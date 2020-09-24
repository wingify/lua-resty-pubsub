use Test::Nginx::Socket "no_plan";

use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty/lualib/?.so;;";
};

run_tests();

__DATA__

=== TEST 1: Create Pubsub Producer

--- http_config eval: $::HttpConfig
--- config
location = /t {
    content_by_lua '
        local producer = require "resty.pubsub.producer"

        local create_producer = function()

            local pubsub_config = {
                project_id = "project-1",
                topic = "topic-1",
                oauth_config = {
                    service_account_key_path = "./test.json"
                }
            }

            local p, err = producer:new(pubsub_config)
            if err ~= nil then
                return
            end

            ngx.print("Producer Created");

        end

        create_producer()
    ';
}
--- request
GET /t
--- response_body
Producer Created