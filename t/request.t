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
            local project_id = "test-project"

            local pubsub_config = {
                topic = "test-topic",
                pubsub_base_domain = "pubsub.googleapis.com",
                pubsub_base_port = 443
            }

            local producer_config = {
                max_batch_size = 200,
                max_buffering = 5000,
                timer_interval = 5000,
                last_flush_interval = 5000,
                http_timeout = 5000,
                keepalive_max_idle_timeout = 10000,
                keepalive_pool_size = 1
            }


            local oauth_config = {
                service_account_key_path = "./test.json",
                oauth_base_uri = "https://www.googleapis.com/oauth2/v4/token",
                oauth_scopes = { 
                    "https://www.googleapis.com/auth/pubsub"
                }
            }

            local req = request:new(project_id, pubsub_config, producer_config, oauth_config)
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