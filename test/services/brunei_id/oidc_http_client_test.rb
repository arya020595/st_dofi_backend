require "test_helper"

# Assertions cover the provider wire contract, including PKCE and bearer headers.
# rubocop:disable Minitest/MultipleAssertions
class BruneiId::OidcHttpClientTest < ActiveSupport::TestCase
  test "token exchange preserves the URL-encoded provider request" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("https://brunei.test/token") do |env|
        assert_equal "application/x-www-form-urlencoded", env.request_headers["Content-Type"]
        assert_equal({ "grant_type" => "authorization_code", "code" => "opaque-code", "client_id" => "client-id",
                       "client_secret" => "client-secret", "redirect_uri" => "https://app.test/callback",
                       "code_verifier" => "pkce-verifier" }, Rack::Utils.parse_nested_query(env.body))
        [200, {}, { id_token: "signed-token", access_token: "provider-token" }.to_json]
      end
    end

    response = client_for(stubs).exchange_code(
      "https://brunei.test/token", code: "opaque-code", code_verifier: "pkce-verifier",
                                   redirect_uri: "https://app.test/callback"
    )

    assert_equal({ "id_token" => "signed-token", "access_token" => "provider-token" }, response)
    stubs.verify_stubbed_calls
  end

  test "discovery JWKS and userinfo preserve their endpoints and headers" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("https://brunei.test/.well-known/openid-configuration") { [200, {}, '{"issuer":"brunei"}'] }
      stub.get("https://brunei.test/jwks") { [200, {}, '{"keys":[]}'] }
      stub.get("https://brunei.test/userinfo") do |env|
        assert_equal "Bearer provider-token", env.request_headers["Authorization"]
        [200, {}, '{"name":"Verified Name"}']
      end
    end
    client = client_for(stubs)

    assert_equal({ "issuer" => "brunei" }, client.fetch_discovery_document)
    assert_equal({ "keys" => [] }, client.fetched_jwks("https://brunei.test/jwks"))
    assert_equal({ "name" => "Verified Name" },
                 client.fetch_userinfo(discovery: { "userinfo_endpoint" => "https://brunei.test/userinfo" },
                                       access_token: "provider-token"))
    stubs.verify_stubbed_calls
  end

  test "provider failure statuses continue raising Faraday errors" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("https://brunei.test/jwks") { [401, {}, '{"error":"invalid_token"}'] }
    end

    assert_raises(Faraday::BadRequestError) { client_for(stubs).fetched_jwks("https://brunei.test/jwks") }
  end

  test "network failures propagate while optional userinfo failures remain empty" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("https://brunei.test/jwks") { raise Faraday::TimeoutError }
      stub.get("https://brunei.test/userinfo") { raise Faraday::ConnectionFailed }
    end
    client = client_for(stubs)

    assert_raises(Faraday::TimeoutError) { client.fetched_jwks("https://brunei.test/jwks") }
    assert_empty client.fetch_userinfo(discovery: { "userinfo_endpoint" => "https://brunei.test/userinfo" },
                                       access_token: "provider-token")
  end

  private

  def client_for(stubs)
    connection = Faraday.new do |faraday|
      faraday.request :url_encoded
      faraday.adapter :test, stubs
    end
    TestClient.new(connection:)
  end

  class TestClient < BruneiId::OidcHttpClient
    def client_id = "client-id"

    private

    def base_url = "https://brunei.test"
    def client_secret = "client-secret"
  end
end
# rubocop:enable Minitest/MultipleAssertions
