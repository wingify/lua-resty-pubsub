--[[
	The MIT License (MIT)

	Copyright (c) 2020 Wingify Software Pvt. Ltd.

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]


-- Storing all the default values used in this library

local _M = {}

_M.PUBSUB_BASE_PORT = 443

_M.PUBSUB_BASE_DOMAIN = "pubsub.googleapis.com"

_M.IS_EMULATOR = false

_M.DISABLE_SSL = false

_M.OAUTH_BASE_URI  = "https://www.googleapis.com/oauth2/v4/token"

_M.OAUTH_SCOPES = {
	"https://www.googleapis.com/auth/pubsub"
}

_M.MAX_BATCH_SIZE = 200

_M.MAX_BUFFERING = 5000

_M.TIMER_INTERVAL = 10000 -- in millis

_M.LAST_FLUSH_INTERVAL = 10000 -- in millis

_M.HTTP_TIMEOUT = 5000 -- in millis

_M.KEEPALIVE_MAX_IDLE_TIMEOUT = 2000 -- in millis

_M.KEEPALIVE_POLL_SIZE = 50

_M.OAUTH_TOKEN_EXPIRY = 3600 -- in seconds

_M.OAUTH_TOKEN_DICT = ngx.shared.OAUTH_TOKEN

_M.WORKLOAD_IDENTITY_TOKEN_URL = "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token"

return _M