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
            local project_id = "project-1"

            local pubsub_config = {
                topic = "topic-1"
            }

            local oauth_config = {
                service_account_key_path = "./test.json"
            }

            local p, err = producer:new(project_id, pubsub_config, nil, oauth_config)
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