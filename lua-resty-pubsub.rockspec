package = "lua-resty-pubsub"
version = "1.5-0"
source = {
   url = "git://github.com/wingify/lua-resty-pubsub",
   tag = "v1.5"
}
description = {
   summary = "Lua Pubsub client driver for the ngx_lua based on the cosocket API",
   detailed = [[
    This Lua library is a Pubsub client driver for the ngx_lua nginx module: http://wiki.nginx.org/HttpLuaModule

    This Lua library takes advantage of ngx_lua's cosocket API, which ensures 100% nonblocking behavior. This library pushes messages (with attributes) to Google Cloud pubsub using nginx timers and http requests.

    Note that at least [ngx_lua 0.9.3](https://github.com/openresty/lua-nginx-module/tags) or [ngx_openresty 1.4.3.7](http://openresty.org/#Download) is required, and unfortunately only LuaJIT supported (`--with-luajit`).
   ]],
   homepage = "https://github.com/wingify/lua-resty-pubsub",
   license = "MIT",
   maintainer = "Vasu Gupta <https://github.com/Vasu7052>"
}
dependencies = {
   "lua >= 5.1",
   "lua-cjson >= 2.1.0.6",
   "lua-resty-rsa >= 0.04",
   "lua-resty-http >= 0.15"
}
build = {
   type = "builtin",
   modules = {
      ["resty.pubsub.constants"] = "lib/resty/pubsub/constants.lua",
      ["resty.pubsub.oauth_client"] = "lib/resty/pubsub/oauth_client.lua",
      ["resty.pubsub.producer"] = "lib/resty/pubsub/producer.lua",
      ["resty.pubsub.request"] = "lib/resty/pubsub/request.lua",
      ["resty.pubsub.ringbuffer"] = "lib/resty/pubsub/ringbuffer.lua"
   }
}