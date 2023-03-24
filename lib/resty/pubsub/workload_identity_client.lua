--[[
	The MIT License (MIT)

	Copyright (c) 2020 Wingify Software Pvt. Ltd.

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]


local ngx = require "ngx"
local cjson = require "cjson"
local io = require "io"
local resty_rsa = require "resty.rsa"
local http = require "resty.http"
local constants = require "resty.pubsub.constants"

local setmetatable = setmetatable

local _M = {}
local mt = { __index = _M }

function _M.new(self, workload_identity_config, topic)

	local instance = {
		topic = topic,
		token_url = workload_identity_config.token_url, -- http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
		token_expires = 0, -- We need to maintain token expiry time so that we can update it before expiring
		token_dict = workload_identity_config.token_dict
	}

	return setmetatable(instance, mt)
end

-- A method which sets the token to a lua dictionary.
local function token_setter(self, token, expires_in)
  self.token_dict:set("token:" .. self.topic, token)
end

-- A method which gets token from a lua dictionary.
local function token_getter(self)
  return self.token_dict:get("token:" .. self.topic)
end

function _M.get_token(self)

	if self.token_dict == nil then
		return nil, "Provided token lua dictionary not found, please refer to documentation for adding it to nginx configuration"
	end

	local status, token = pcall(function () 
    if token_getter(self) == nil or (ngx_time() > token_expires) then
      local httpc = http.new()
      local res, err = httpc:request_uri(self.token_url, {
        headers = {
          ["Metadata-Flavor"] = "Google"
        }
      })

      if not res then
        return {nil, err}
      end

      if res.status >=400 then
        return {nil, cjson.decode(res.body)}
      end

      local decoded_response = cjson.decode(res.body)
      local token = decoded_response["access_token"]
      self.token_expires = ngx.time() + decoded_response["expires_in"]

      token_setter(self, token)
      return {token, nil}
    else
      return {token_getter(self), nil}
    end
	end)

	if not status then
		return nil, token -- If something fails while executing callback, token object will comprise of the callback error
	else
		return table.unpack(token) -- Else return a table consisting of data & error (if any)
	end
end

return _M