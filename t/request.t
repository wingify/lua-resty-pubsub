use Test::Nginx::Socket "no_plan";

use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty/lualib/?.so;;";
};

run_tests();

__DATA__

=== TEST 1: Create Pubsub Request Object

--- http_config eval: $::HttpConfig
--- config
location = /t {
    content_by_lua '
        local request = require "resty.pubsub.request"

        local create_request = function()
            local pubsub_config = {
                project_id = "test-project",
                topic = "test-topic",
                pubsub_base_domain = "pubsub.googleapis.com",
                pubsub_base_port = 443,
                is_emulator = false,
                producer_config = {
                    max_batch_size = 200,
                    max_buffering = 5000,
                    timer_interval = 5000,
                    last_flush_interval = 5000,
                    http_timeout = 5000,
                    keepalive_max_idle_timeout = 10000,
                    keepalive_pool_size = 1
                }
            }

            local req = request:new(pubsub_config, nil)
            if req == nil then
                return
            end

            ngx.print("Request Object Created");

        end

        create_request()
    ';
}
--- request
GET /t
--- response_body
Request Object Created