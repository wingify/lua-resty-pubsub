--[[
	The MIT License (MIT)

	Copyright (c) 2020 Wingify Software Pvt. Ltd.

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]


local ngx = require "ngx"
local cjson = require "cjson"
local http = require "resty.http"

local setmetatable = setmetatable

local _M = {}
local mt = { __index = _M }

function _M.new(self, project_id, pubsub_config, producer_config, oauth_client)

    local instance = {
        project_id = project_id,
        pubsub_topic = pubsub_config.topic,
        pubsub_base_domain = pubsub_config.pubsub_base_domain,
        pubsub_base_port = pubsub_config.pubsub_base_port,
        http_timeout = producer_config.http_timeout,
        keepalive_max_idle_timeout = producer_config.keepalive_max_idle_timeout,
        keepalive_pool_size = producer_config.keepalive_pool_size,
        oauth_client = oauth_client
    }

    return setmetatable(instance, mt)
end

function _M.batch_send(self, encoded_messages)
	--[[
		Push messages in batch to the specified pubsub topic.
		@Parameter: Batch Messages to be send
			Table of messages to be pushed.
    ]]

    local path = "/v1/projects/" .. self.project_id .. "/topics/" .. self.pubsub_topic .. ":publish"

    local oauth_token, oauth_err = self.oauth_client:get_oauth_token()
    if oauth_err ~= nil then
        return false, self.pubsub_topic, oauth_err, encoded_messages
    end

	local httpc = http.new()

	-- Specifying the timeout for subsequent operations
    httpc:set_timeout(self.http_timeout)

    -- Connecting to pubsub endpoint for making request
    httpc:connect(self.pubsub_base_domain, self.pubsub_base_port)

    -- And request using a path, rather than a full URI.
    local handshake_res, handshake_err = httpc:ssl_handshake(nil, self.pubsub_base_domain, false)
    if not handshake_res then
        ngx.log(ngx.ERR, "Got error in handshake = ", handshake_err)
        return false, self.pubsub_topic, handshake_err, encoded_messages
    end

    -- Send final request to pubsub endpoint
    local res, res_err = httpc:request({
        path = path,
        method = "POST",
        headers = {
            ["Content-Type"]  = "application/json",
            ["Authorization"] = "Bearer " .. oauth_token,
        },
        body = cjson.encode({messages = encoded_messages}),
        ssl_verify = false
    })

    -- Check for response
    if not res then
        return false, self.pubsub_topic, res_err, encoded_messages
    end

    -- Reading the bidy cintent from teh response
    local body, body_err = res:read_body()
    if not body then
        return false, self.pubsub_topic, body_err, encoded_messages
    end

    res.body = body

    -- Check for any error in response
    if tonumber(res.status) >= 400 then
        local pubsub_err = cjson.decode(res.body)["error"]
        return false, self.pubsub_topic, pubsub_err, encoded_messages
    end

    -- Setting http keepalive for connection reuse
    local ok, err = httpc:set_keepalive(self.keepalive_max_idle_timeout, self.keepalive_pool_size)
    if not ok then
        return false, self.pubsub_topic, err, encoded_messages
    end

    return true, self.pubsub_topic, nil, encoded_messages
end

return _M