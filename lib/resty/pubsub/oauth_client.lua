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
local OAUTH_TOKEN = ngx.shared.OAUTH_TOKEN

local setmetatable = setmetatable

local _M = {}
local mt = { __index = _M }

function _M.new(self, oauth_config)

	local instance = {
		service_account_key_path = oauth_config.service_account_key_path,
		oauth_base_uri = oauth_config.oauth_base_uri,
		oauth_scopes = oauth_config.oauth_scopes,
		oauth_token_time = 0 -- We need to maintain token fetch time so that we can update it before expiring
	}

	return setmetatable(instance, mt)
end

-- A method which sets the generated oauth token to a lua dictionary.
local function oauth_setter(self, oauth_token)
    OAUTH_TOKEN:set("token", oauth_token)
end

-- A method which get the generated oauth token from a lua dictionary.
local function oauth_getter(self)
    return OAUTH_TOKEN:get("token")
end

local function get_jwt_payload(self, credentials)
	--[[
		Prepares the JSON payload string for JWT generation as specified in
		developers.google.com/identity/protocols/OAuth2ServiceAccount.

		@Parameter: credentials
			table obtained from reading service-account-key JSON file
	]]
	local client_email = credentials["client_email"]
	if not client_email then
		return nil
	end
	local iat	= ngx.time()
	local expt	= iat + constants.OAUTH_TOKEN_EXPIRY
	local aud   =  self.oauth_base_uri
	local scopes = ""
	for i, scope in ipairs(self.oauth_scopes) do
		scopes = scopes .. scope
		if i < #self.oauth_scopes then
			scopes = scopes .. " "
		end
	end

	-- Due to the lack of a working JWT lua client library the string corressponding to
	-- JSON payload has to be constructed manually
	local payload = "{" .. '"iss"' .. ":" .. '"' .. client_email ..'"' .. "," ..
					 '"scope"' .. ":" ..'"' .. scopes ..'"' .. ","  ..
					 '"aud"' .. ":" ..'"' .. aud ..'"'.. "," ..
					 '"exp"' .. ":" .. tostring(expt)  .. "," ..
					 '"iat"' .. ":"  .. tostring(iat)  .. "}"
    return payload
end

local function get_gcp_credentials(self)
	--[[
		Returns a table having the necessary gcp credentials by first looking for the
		table in object variable and if not found there then read from service key account
		JSON file.
	]]
	if not self.gcp_credentials_json_text then
		local service_account_key_path = self.service_account_key_path
		local file, file_err = io.open(service_account_key_path,"r")
		if not file then
			return nil, file_err
		end
	    self.gcp_credentials_json_text = file:read("*a")
	    file:close()
	end
	return cjson.decode(self.gcp_credentials_json_text)
end

local function get_jwt_token(self)
	--[[
		Returns JWT by applying RS256 algorithm on the payload and
		the private key read from service account key JSON file.
	]]
	local credentials, credentials_err = get_gcp_credentials(self)
	if not credentials then
		return nil, credentials_err
	end

	local jwt_header  = '{"alg":"RS256","typ":"JWT"}'
	local jwt_payload = get_jwt_payload(self, credentials)
	if not jwt_payload then
		return nil, "Unable to generate JWT Payload"
	end

	-- Implementation of JWT algorithm.Refer to jwt.io for algorithm details
	local b64_string_to_sign = ngx.encode_base64(jwt_header) .. "." .. ngx.encode_base64(jwt_payload)
	b64_string_to_sign = b64_string_to_sign:gsub('+','-'):gsub('/','_'):gsub('=','')
	local priv = resty_rsa:new({ private_key = credentials['private_key'], algorithm = "SHA256"})
	local jwt_hash , err = priv:sign(b64_string_to_sign)
	if not jwt_hash then
		return nil, err
	end

	local b64_jwt_hash = ngx.encode_base64(jwt_hash)
	b64_jwt_hash = b64_jwt_hash:gsub('+','-'):gsub('/','_'):gsub('=','')
	return b64_string_to_sign .. "." .. b64_jwt_hash
end

local function refresh_oauth_token(self)
	ngx.log(ngx.INFO, "Refreshing OAUTH Token")

	local jwt_token, err = get_jwt_token(self)
	if not jwt_token then
		return nil, err
	end
	local data = {
		grant_type = 'urn:ietf:params:oauth:grant-type:jwt-bearer',
		assertion  =  jwt_token
	}

	-- Send request to Google authorization server for a token that will be used in subsequent requests till token expiry
	local httpc = http.new()
	local uri = self.oauth_base_uri
	local res, err = httpc:request_uri(uri,{
	    method = "POST",
	    body   = cjson.encode(data),
	    ssl_verify = false
	  })
	if not res then
		return nil, err
	end

	if res.status >=400 then
		local oauth_err = cjson.decode(res.body)
		return nil, oauth_err
	end
	return cjson.decode(res.body)["access_token"], nil
end

function _M.get_oauth_token(self)
	if oauth_getter(self) == nil or (ngx.time() - self.oauth_token_time >= constants.OAUTH_TOKEN_EXPIRY) then
		local oauth_token, err = refresh_oauth_token(self)
		oauth_setter(self, oauth_token)
		self.oauth_token_time = ngx.time()
		return oauth_getter(self), err
	else
		return oauth_getter(self), nil
	end
end

return _M