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

=== TEST 1: Create Workload Identity Client

--- http_config eval: $::HttpConfig
--- config
location = /token {
    default_type application/json;
    return 200 '{"access_token":"foobar", "expires_in": 3599, "token_type": "Bearer"}';
}

location = /t {
    content_by_lua '
        local OAUTH_TOKEN = ngx.shared.OAUTH_TOKEN
        local workload_identity_client = require "resty.pubsub.workload_identity_client"

        local create_workload_identity_client = function()
            local topic = "topic"
            local workload_identity_config = {
                token_url = "http://127.0.0.1:1984/token",
                token_dict = OAUTH_TOKEN
            }

            local auth_client = workload_identity_client:new(workload_identity_config, topic)
            if auth_client == nil then
                return
            end

            local token, err = auth_client:get_token()

            if err ~= nil then
                ngx.log(ngx.ERR, "Error: ", err)
                return
            end

            ngx.print(token)
        end

        create_workload_identity_client()
    ';
}
--- request
GET /t
--- response_body
foobar