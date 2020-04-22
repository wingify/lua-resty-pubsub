--[[
	The MIT License (MIT)

	Copyright (c) 2020 Wingify Software Pvt. Ltd.

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]


local ngx = require "ngx"
local is_exiting = ngx.worker.exiting
local cjson = require "cjson"
local constants = require "resty.pubsub.constants"
local ringbuffer = require "resty.pubsub.ringbuffer"
local request = require "resty.pubsub.request"
local oauthclient = require "resty.pubsub.oauth_client"

local setmetatable = setmetatable

local _M = {}
local mt = { __index = _M }

-- Keeping track of instances that are created for each topic
local instances = {}

-- Acquiring flush lock
local function _flush_lock(self)
    if not self.is_flushing then
        self.is_flushing = true
        return true
    end
    return false
end

-- Releasing flush lock
local function _flush_unlock(self)
    self.is_flushing = false
end

-- Creating final batch that needs to be pushed to pubsub
local function push_batch(self)
    local batch = {}
    local buffer = self.ring_buffer
    while true do
        local message = buffer:pop()
        if not message then
            break
        end
        message.data = ngx.encode_base64(message.data) -- Encoding message to base64 before sending to pubsub
        batch[#batch + 1] = message
        -- There is a limit for pushing message to pubsub in request body
        if #batch >= self.producer_config.max_batch_size then
            break
        end
    end

    -- Final Call to Pubsub Producer to send data
    local status, topic, err, messages = self.request:batch_send(batch)

    if not status then
        if self.error_handler ~= nil then
            -- Provide original data to the callback
            for _, message in ipairs(messages) do
                message.data = ngx.decode_base64(message.data)
            end
            local ok, callback_err = pcall(self.error_handler, topic, err, messages)
            if not ok then
                ngx.log(ngx.ERR, "failed for callback error_handler: ", cjson.encode(callback_err))
            end
        end
    else
        if self.success_handler ~= nil then
            -- Provide successfull original data to the callback
             for _, message in ipairs(messages) do
                message.data = ngx.decode_base64(message.data)
            end
            local ok, callback_err = pcall(self.success_handler, topic, nil, messages)
            if not ok then
                ngx.log(ngx.ERR, "failed for callback success_handler: ", cjson.encode(callback_err))
            end
        end
    end

    return batch
end

local _flush_buffer

-- This runs in seperate nginx timer context which is responsible for pushing entire batch
local function _flush(premature, self)

    if not _flush_lock(self) then
        return
    end

    if premature then
        push_batch(self)
        self.last_flush = ngx.time()
    end

    push_batch(self)
    self.last_flush = ngx.time()

    _flush_unlock(self)

    -- When the process is existing we need to send the left over packets as well
    if is_exiting() and self.ring_buffer:left_num() > 0 then
        -- still can create 0 timer even exiting
        _flush_buffer(self)
    end

end

-- This launches a timer whenever required
function _flush_buffer(self)
    local ok, err = ngx.timer.at(0, _flush, self)
    if not ok then
        ngx.log(ngx.WARN, "failed to create timer at _flush_buffer, err: ", err)
    end
end

-- We also need a background thread to check if size of ringbuffer is less than
-- the batch size for a certain interval of time. We need to flush them as well.
local _timer_flush
_timer_flush = function (premature, self, time)

    if premature then
        push_batch(self)
        self.last_flush = ngx.time()
        return
    end

    if not self.is_flushing and self.ring_buffer:left_num() > 0 and
            (ngx.time() - self.last_flush > self.producer_config.last_flush_interval) then
        _flush_buffer(self)
    end

    local ok, err = ngx.timer.at(time, _timer_flush, self, time)
    if not ok then
        ngx.log(ngx.WARN, "failed to create timer at _timer_flush, err: ", err)
    end
end

function _M.send(self, message, attributes)

    if type(message) ~= "string" then
        return false, "Data expected in string, got " .. type(message)
    end

    if type(attributes) ~= "table" then
        return false, "Attributes expected as a table, got " .. type(attributes)
    end

    -- Creating a pubsub message for http body
    local body_message = {
        data = message,
        attributes = attributes
    }

    if self.ring_buffer == nil then
        return false, "Buffer not initialized Properly"
    end

    -- Adding packets to ring buffer
    local _, err = self.ring_buffer:add(body_message)

    if err ~= nil then
        return false, err
    end

    -- Only send flush signal when there is no ongoing flush and ringbuffer has enough size to create batch
    if not self.is_flushing and (self.ring_buffer:need_send() or is_exiting()) then
        _flush_buffer(self)
    end

    return true, nil
end

-- Replacing optional configs with default values if not provided
local function normalize_configs(self, pubsub_config, producer_config, oauth_config)

    pubsub_config.pubsub_base_domain = pubsub_config.pubsub_base_domain or constants.PUBSUB_BASE_DOMAIN
    pubsub_config.pubsub_base_port = pubsub_config.pubsub_base_port or constants.PUBSUB_BASE_PORT

    if producer_config == nil then
        producer_config = {}
    end

    producer_config.max_batch_size = producer_config.max_batch_size or constants.MAX_BATCH_SIZE
    producer_config.max_buffering = producer_config.max_buffering or constants.MAX_BUFFERING
    producer_config.timer_interval = (producer_config.timer_interval or constants.TIMER_INTERVAL) / 1000
    producer_config.last_flush_interval = (producer_config.last_flush_interval or constants.LAST_FLUSH_INTERVAL) / 1000
    producer_config.http_timeout = producer_config.http_timeout or constants.HTTP_TIMEOUT
    producer_config.keepalive_max_idle_timeout = producer_config.keepalive_max_idle_timeout or constants.KEEPALIVE_MAX_IDLE_TIMEOUT
    producer_config.keepalive_pool_size = producer_config.keepalive_pool_size or constants.KEEPALIVE_POLL_SIZE

    oauth_config.oauth_base_uri = oauth_config.oauth_base_uri or constants.OAUTH_BASE_URI
    oauth_config.oauth_scopes = oauth_config.oauth_scopes or constants.OAUTH_SCOPES

    return pubsub_config, producer_config, oauth_config
end

-- Check if necessary config is provided
local function check_mandatory_config(self, project_id, pubsub_config, producer_config, oauth_config, oauth_setter, oauth_getter)
    if not project_id then
        return false, "Project id not provided"
    end

    if pubsub_config == nil or pubsub_config == {} then
        return false, "Pubsub Config not provided"

    end

    if pubsub_config.topic == nil then
        return false, "Pubsub topic not provided"
    end

    if oauth_config == nil or oauth_config == {} then
        return false, "Oauth Config not provided"
    end

    if oauth_config.service_account_key_path == nil then
        return false, "Service Account key Path not provided"
    end

    if oauth_setter ~= nil and oauth_getter == nil then
        return false, "Oauth Getter must be defined if Oauth setter is being used"
    end

    if oauth_getter ~= nil and oauth_setter == nil then
        return false, "Oauth Setter must be defined if Oauth Getter is being used"
    end

    if producer_config ~= nil and type(producer_config.max_batch_size) == "number" and producer_config.max_batch_size > 1000 then
        return false, "Max Batch Size must be <= 1000"
    end

    return true, nil
end

function _M.new(self, project_id, pubsub_config, producer_config, 
    oauth_config, success_handler, error_handler, oauth_setter, oauth_getter)

    local _, err = check_mandatory_config(self, project_id, pubsub_config, producer_config, oauth_config, oauth_setter, oauth_getter)
    if err ~= nil then
        return nil, err
    end

    pubsub_config, producer_config, oauth_config = normalize_configs(self, pubsub_config, producer_config, oauth_config)

    -- Create only one instance of pubsub producer per topic per worker process
    if instances[pubsub_config.topic] ~= nil then
        return instances[pubsub_config.topic]
    end

    ngx.log(ngx.DEBUG, "Creating producer for topic: ", pubsub_config.topic)

    -- Creating an instance of OAUTH 2.0 client for generating oauth token
    local oauth_client = oauthclient:new(oauth_config, oauth_setter, oauth_getter)

    local instance = {
        project_id = project_id,
        pubsub_config = pubsub_config,
        producer_config = producer_config,
        oauth_config = oauth_config,
        success_handler = success_handler,
        error_handler = error_handler,
        last_flush = ngx.time(), -- We also need to track when the last batch flush was occured
        ring_buffer = ringbuffer:new(producer_config.max_batch_size, producer_config.max_buffering), -- For storing buffered data
        request = request:new(project_id, pubsub_config, producer_config, oauth_client), -- For sending request to pubsub domain
        oauth_client = oauth_client
    }

    _timer_flush(nil, instance, producer_config.timer_interval)

    instances[pubsub_config.topic] = instance

    return setmetatable(instance, mt), nil
end

return _M