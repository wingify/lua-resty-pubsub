use Test::Nginx::Socket "no_plan";

use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty/lualib/?.so;;";
    lua_shared_dict     OAUTH_TOKEN 1m;
};

run_tests();

__DATA__

=== TEST 1: Create Pubsub Producer

--- http_config eval: $::HttpConfig
--- config
location = /token {
    default_type application/json;
    return 200 '{"access_token":"foobar", "expires_in": 3599, "token_type": "Bearer"}';
}
location = /v1/projects/test/topics/test:publish {
    return 200 "ok";
}
location = /t {
    content_by_lua '
        local producer = require "resty.pubsub.producer"

        local create_producer = function()
            local pubsub_config = {
                project_id = "test",
                topic = "test",
                pubsub_base_domain = "127.0.0.1",
                pubsub_base_port = 1984,
                is_emulator = false,
                disable_ssl = true,
                producer_config = {
                    max_batch_size = 1, -- number of packets
                    timer_interval = 1, -- in milliseconds
                    last_flush_interval = 1, -- in milliseconds
                },
                workload_identity_config = {
                    token_url = "http://127.0.0.1:1984/token",
                    token_dict = OAUTH_TOKEN
                }
            }

            local p, err = producer:new(pubsub_config)

            if err ~= nil then
                return
            end

            pcall(function()
                local ok, send_err = p:send("Some Random Text", {
                    attr1 = "Test1",
                    attr2 = "Test2"
                })

                if send_err ~= nil then
                    ngx.print("Error: ", send_err)
                    return
                end

                os.execute("sleep 1")

                ngx.print("Success")
            end)


        end

        create_producer()
    ';
}
--- request
GET /t
--- response_body
Success