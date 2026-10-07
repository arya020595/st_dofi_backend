require "test_helper"

# These assertions cover the full authentication boundary: provider HTTP, signed identity,
# persisted account state, response metadata, and both application tokens.
class BruneiIdOidcLoginTest < ActionDispatch::IntegrationTest
  CALLBACK_PARAMS = { code: "authorization-code", code_verifier: "pkce-verifier", nonce: "nonce-1",
                      redirect_uri: "https://app.test/callback" }.freeze

  setup do
    @key = OpenSSL::PKey::RSA.generate(2048)
    @jwk = JWT::JWK.new(@key)
  end

  test "verified provider identity claims a fisherman and issues usable tokens with profile metadata" do
    user = create(:user, :fins_governed_fisherman, fisherman_status: "claimable",
                                                   claimed_at: nil, brunei_id_verified_at: nil)

    perform_callback(user, audience: "fisherman")

    assert_response :ok
    assert_equal "active", user.reload.fisherman_status
    assert_predicate user, :claimed_at?
    assert_predicate user, :brunei_id_verified_at?
    assert_authenticated_response(user)
  end

  test "verified provider identity authenticates an active jetty manager" do
    user = create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER))

    perform_callback(user, audience: "jetty_manager")

    assert_response :ok
    assert_authenticated_response(user)
  end

  test "a provider token with the wrong signature cannot claim an account or issue tokens" do
    user = create(:user, :fins_governed_fisherman, fisherman_status: "claimable",
                                                   claimed_at: nil, brunei_id_verified_at: nil)

    perform_callback(user, audience: "fisherman", signing_key: OpenSSL::PKey::RSA.generate(2048))

    assert_response :unauthorized
    assert_equal "token_validation_failed", response.parsed_body["code"]
    assert_equal ["claimable", nil, nil],
                 [user.reload.fisherman_status, user.claimed_at, user.brunei_id_verified_at]
    assert_nil response.headers["Authorization"]
    assert_empty Current.attributes.values.compact
  end

  private

  def perform_callback(user, audience:, signing_key: @key)
    stubs = provider_stubs(signed_identity_for(user, signing_key), userinfo: signing_key.equal?(@key))
    callback = BruneiId::OidcCallback.new(client: TestClient.new(connection: connection_for(stubs)))
    with_brunei_id_callback(callback) do
      post "/api/v1/auth/brunei_id/callback", params: CALLBACK_PARAMS.merge(audience:), as: :json
    end
    stubs.verify_stubbed_calls
  end

  def signed_identity_for(user, signing_key)
    claims = { icnumber: user.ic_number, name: "Verified Name", sub: "provider-subject", nonce: "nonce-1",
               iss: "https://brunei.test/", aud: "test-client", exp: 5.minutes.from_now.to_i }
    JWT.encode(claims, signing_key, "RS256", kid: @jwk.kid)
  end

  def connection_for(stubs)
    Faraday.new do |faraday|
      faraday.request :url_encoded
      faraday.adapter :test, stubs
    end
  end

  def provider_stubs(token, userinfo:)
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("https://brunei.test/.well-known/openid-configuration") { [200, {}, discovery.to_json] }
      stub.post("https://brunei.test/token") { |env| token_exchange_response(env, token) }
      stub.get("https://brunei.test/jwks") { [200, {}, { keys: [@jwk.export] }.to_json] }
      stub.get("https://brunei.test/userinfo") { |env| userinfo_response(env) } if userinfo
    end
  end

  def token_exchange_response(env, token)
    assert_equal({ "grant_type" => "authorization_code", "code" => CALLBACK_PARAMS[:code],
                   "code_verifier" => CALLBACK_PARAMS[:code_verifier], "client_id" => "test-client",
                   "client_secret" => "test-secret", "redirect_uri" => CALLBACK_PARAMS[:redirect_uri] },
                 Rack::Utils.parse_nested_query(env.body))
    [200, {}, { id_token: token, access_token: "provider-token", token_type: "Bearer",
                expires_in: 300, scope: "openid" }.to_json]
  end

  def userinfo_response(env)
    assert_equal "Bearer provider-token", env.request_headers["Authorization"]
    [200, {}, { family_name: "Family" }.to_json]
  end

  def discovery
    { issuer: "https://brunei.test/", token_endpoint: "https://brunei.test/token",
      jwks_uri: "https://brunei.test/jwks", userinfo_endpoint: "https://brunei.test/userinfo",
      id_token_signing_alg_values_supported: ["RS256"] }
  end

  def assert_authenticated_response(user)
    data = response.parsed_body.fetch("data")

    assert_profile_metadata(data, user)
    assert_session_tokens(data, user)
    get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{data.fetch('access_token')}" }

    assert_response :ok
    assert_equal user.id, response.parsed_body.dig("data", "user", "id")
  end

  def assert_profile_metadata(data, user)
    assert_equal "dashboard", data["next_action"]
    assert_equal({ "ic_number" => user.ic_number, "full_name" => "Verified Name",
                   "family_name" => "Family", "subject" => "provider-subject" }, data["brunei_id_profile"])
    assert_equal({ "token_type" => "Bearer", "expires_in" => 300, "scope" => "openid",
                   "response_keys" => %w[id_token access_token token_type expires_in scope] },
                 data["brunei_id_token_metadata"])
  end

  def assert_session_tokens(data, user)
    assert_equal user, Realtime::CableToken.user_for(data.fetch("realtime_token"))
    assert_equal "Bearer #{data.fetch('access_token')}", response.headers["Authorization"]
    assert_empty Current.attributes.values.compact
  end

  class TestClient < BruneiId::OidcHttpClient
    def client_id = "test-client"

    private

    def base_url = "https://brunei.test"
    def client_secret = "test-secret"
    def configured_redirect_uri = CALLBACK_PARAMS[:redirect_uri]
  end
end
