# lua-resty-pubsub

Lua Pubsub client driver for the `ngx_lua` based on the cosocket API

## Table of Contents

* [Description](#description)
* [Synopsis](#synopsis)
* [Configs](#configs)
* [Modules](#modules)
    * [resty.pubsub.producer](#restypubsubproducer)
        * [Methods](#methods)
            * [new](#new)
            * [send](#send)
* [Dependencies](#dependencies)
* [Installation](#installation)
* [TODO](#todo)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

## Description

This Lua library is a Pubsub client driver for the ngx_lua nginx module: http://wiki.nginx.org/HttpLuaModule

This Lua library takes advantage of ngx_lua's cosocket API, which ensures 100% nonblocking behavior. This library pushes messages (with attributes) to Google Cloud pubsub using nginx timers and http requests.

Note that at least [ngx_lua 0.9.3](https://github.com/openresty/lua-nginx-module/tags) or [ngx_openresty 1.4.3.7](http://openresty.org/#Download) is required, and unfortunately only LuaJIT supported (`--with-luajit`).

## Synopsis

```lua
    lua_package_path "/path/to/lua-resty-pubsub/lib/?.lua;;";

    server {
        location = /test {
            resolver 8.8.8.8 ipv6=off;

            content_by_lua_block {
                local cjson = require "cjson"
                local pubsub_producer = require "resty.pubsub.producer"
                local OAUTH_TOKEN = ngx.shared.OAUTH_TOKEN -- Just for the sake of this example

                -- A callback which will recieve messages if gets successfully sent
                -- Types of messages & err are a table
                local success_callback = function (topic, err, messages)
                    ngx.log(ngx.ERR, "Messages: ", cjson.encode(messages), " successfully pushed to topic: ", topic)
                end

                -- A callback which will recieve messages if gets failed
                -- Types of messages & err are a table
                local error_callback = function (topic, err, messages)
                    for _, message in ipairs(messages) do
                        ngx.log(ngx.ERR, "Failed to send Message : ", cjson.encode(message), " with err: ", cjson.encode(err))
                    end
                end

                -- A callback which sets the generated oauth token according to user implementing it. (optional)
                -- In this example we are storing oauth token in a nginx shared dictionary
                local oauth_setter = function (self, oauth_token)
                    OAUTH_TOKEN:set("token", oauth_token)
                end

                -- A callback which get the generated oauth token according to the oauth setter implemention. (optional)
                -- Note: Both oauth_setter and oauth_getter must be provided if atleast one one of them is provided
                local oauth_getter = function (self)
                    return OAUTH_TOKEN:get("token")
                end

                local publish = function()

                    local project_id = "demo-project"

                    local pubsub_config = {
                        topic = "demo-topic",
                        pubsub_base_domain = "pubsub.googleapis.com",
                        pubsub_base_port = 443
                    }

                    local producer_config = {
                        max_batch_size = 200,
                        max_buffering = 5000,
                        timer_interval = 10000, -- in milliseconds
                        last_flush_interval = 5000, -- in milliseconds
                        http_timeout = 6000, -- in milliseconds
                        keepalive_max_idle_timeout = 2000, -- in milliseconds
                        keepalive_pool_size = 50
                    }


                    local oauth_config = {
                        service_account_key_path = "/etc/key.json", -- Replace this with your own key path
                        oauth_base_uri = "https://www.googleapis.com/oauth2/v4/token",
                        oauth_scopes = {
                            "https://www.googleapis.com/auth/pubsub"
                        }
                    }

                    -- Create the producer object
                    -- No matter how many times you call new, the producer instance will always be generated once per topic per worker process
                    local producer, err = pubsub_producer:new(project_id, pubsub_config, producer_config,
                                             oauth_config, success_callback, error_callback, oauth_setter, oauth_getter)

                    -- Also check if there is any error while initializing producer
                    if err ~= nil then
                        ngx.log(ngx.ERR, "Unable to create producer ", err)
                        return
                    end

                    -- Finally send the message with attributes.
                    local ok, send_err = producer:send("Some Random Text", {
                        attr1 = "Test1",
                        attr2 = "Test2"
                    })

                    -- Also check if there is any error while sending message
                    if send_err ~= nil then
                        ngx.log(ngx.ERR, "Unable to send data to pubsub: ", send_err)
                        return
                    end

                end

                -- Publish Message
                publish()
            }

        }
    }
```

## Configs

The `project_id` is a string name of your pub/sub project

A `pubsub_config` table needs to be specified with following options:

* `topic`

    Specifies the topic in which the data needs to be send

* `pubsub_base_domain`

    Specifies the base domain through which the http connection is made. (Optional)

* `pubsub_base_port`

    Specifies the base domain port through which the http connection is made. (Optional)

Example
```json
{
    "topic": "demo-topic",
    "pubsub_base_domain": "pubsub.googleapis.com",
    "pubsub_base_port": 443
}
```

A `producer_config` table needs to be specified which is entirely optional having default values. It's options are:

* `max_batch_size`

    Specifies the max batch size that will be pushed to pubsub. (Optional)

* `max_buffering`

    Specifies the max size of the buffer which will hold the data for a specific duration of time. (Optional)

* `timer_interval`

    Specifies the time interval (in ms) in which the stale messages in buffer are checked for publishing. (Optional)

* `last_flush_interval`

    Specifies the max interval (in ms) between the last flush time and current time. Used when packets in buffer are less than the batch size for a longer period of time. (Optional)

* `http_timeout`

    Sets the timeout (in ms) protection for subsequent operations, including the connect method. (Optional)

* `keepalive_max_idle_timeout` and `keepalive_pool_size`

    Used in httpc:set_keepalive which attempts to puts the current connection into the ngx_lua cosocket connection pool. (Optional)

Example
```json
{
    "max_batch_size" : 200,
    "max_buffering" : 5000,
    "timer_interval" : 10000,
    "last_flush_interval" : 5000,
    "http_timeout" : 6000,
    "keepalive_max_idle_timeout" : 2000,
    "keepalive_pool_size" : 50
}
```

A `oauth_config` table needs to be specified which is used for generating the oauth 2.0 verification for http request. It's options are:

* `service_account_key_path`

    Specifies the path for service account key that are used to authenticate to pub/sub project. (Mandatory)

* `oauth_base_uri`

    Specifies the base uri to which request is made to Google authorization server for a token that will be used in subsequent requests. (Optional)

* `oauth_scopes`

    Specifies a table comprising of OAuth 2.0 scopes that you might need to request to access Google APIs, depending on the level of access you need. (Optional)

Example
```json
{
    "service_account_key_path": "/etc/key.json",
    "oauth_base_uri": "https://www.googleapis.com/oauth2/v4/token",
    "oauth_scopes": {
        "https://www.googleapis.com/auth/pubsub"
    }
}
```

A `success_handler` can also be provide which is optional. This is a callback function which will be provided with all the messages with their attributes which are successfully pushed to pubsub.

A `error_handler` can also be provide which is optional. This is a callback function which will be executed when a batch fails.

A `oauth_setter` can also be provide which is also optional. This is a callback which sets the generated oauth token according to user implementing it. For example, one might need to store oauth token in shared dictionary(as shown in this example) or maybe want to store it in redis etc. If not provided oauth will be set according to the library provided oauth setter.

A `oauth_getter` can also be provide which is also optional (Mandatory if oauth_setter is provided). This is a callback which returns the oauth_token by fetching it from the location where the user has set in oauth_setter. (For better understanding of how this callback works, refer the above given synopsis)

[Back to TOC](#table-of-contents)

## Modules

### resty.pubsub.producer

To load this module, just do this

```lua
    local producer = require "resty.pubsub.producer"
```

[Back to TOC](#table-of-contents)

### Methods

#### new

`syntax: local p, err = producer:new(project_id, pubsub_config, producer_config, oauth_config, success_callback, error_callback, oauth_setter, oauth_getter)`

#### send
`syntax: p:send(message, attributes)`

* Requires a message of type string and attributes of type table

[Back to TOC](#table-of-contents)

## Dependencies

Lua modules required to build this library are:

* [lua-cjson](https://github.com/openresty/lua-cjson.git) library
* [lua-resty-rsa](https://github.com/spacewander/lua-resty-rsa) library
* [lua-resty-http](https://github.com/ledgetech/lua-resty-http) library

## Installation

### For Installing module

#### Method 1 - Using luarocks

For installing luarocks refer [this](https://github.com/luarocks/luarocks/wiki/Download)

You can simply run `luarocks install lua-resty-pubsub` for installing this library

#### Method 2 - Using Makefile

You need to configure
the lua_package_path directive to add the path of your lua-resty-pubsub source
tree to ngx_lua's LUA_PATH search path, as in

```nginx
    # nginx.conf
    http {
        lua_package_path "/path/to/lua-resty-pubsub/lib/?.lua;;";
        ...
    }
```

You also need to add google resolver so as to connect with pubsub endpoints
```nginx
    # default.conf
    server {
        location = /test {
            resolver 8.8.8.8 ipv6=off;
            ...
	    }
    }
```

Ensure that the system account running your Nginx ''worker'' proceses have
enough permission to read the `.lua` file.

Also if using OAUTH_TOKEN dictionary, add `lua_shared_dict` in nginx.conf

Finally run `make install` for installing the module

### For Running Test Cases

Install [Test::Nginx](https://github.com/openresty/test-nginx) module for running test cases

Finally run `make test` for running the test cases

[Back to TOC](#table-of-contents)

## TODO

1.  Pubsub Message Fetch API
2.  Add Unit Test Cases


[Back to TOC](#table-of-contents)

## Author

Vasu Gupta (vasu7052) <https://github.com/Vasu7052>.


[Back to TOC](#table-of-contents)

## Copyright and License

> The MIT License (MIT)
>
> Copyright (c) 2020 Wingify Software Pvt. Ltd.
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


[Back to TOC](#table-of-contents)

## See Also

* the ngx_lua module: http://wiki.nginx.org/HttpLuaModule

[Back to TOC](#table-of-contents)
