use Test::Nginx::Socket "no_plan";

use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty/lualib/?.so;;";
};

run_tests();

__DATA__

=== TEST 1: Create OAUTH 2.0 Client

--- http_config eval: $::HttpConfig
--- config
location = /t {
    content_by_lua '
        local oathclient = require "resty.pubsub.oauth_client"

        local create_oauth_client = function()
            local topic = "topic"
            local oauth_config = {
                service_account_key_path = "t/test.json",
                oauth_base_uri = "https://www.googleapis.com/oauth2/v4/token",
                oauth_scopes = { 
                    "https://www.googleapis.com/auth/pubsub"
                }
            }

            local auth_client = oathclient:new(oauth_config, topic)
            if auth_client == nil then
                return
            end
            
            ngx.print("OAUTH Client Created");
        end

        create_oauth_client()
    ';
}
--- request
GET /t
--- response_body
OAUTH Client Created