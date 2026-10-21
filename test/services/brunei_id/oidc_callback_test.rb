require "test_helper"

module BruneiId
  class OidcCallbackTest < ActiveSupport::TestCase
    CALLBACK_PARAMS = {
      code: "opaque-code", code_verifier: "pkce-verifier",
      redirect_uri: "https://example.test/callback", nonce: "nonce-1"
    }.freeze

    setup do
      @key = OpenSSL::PKey::RSA.generate(2048)
      @jwk = JWT::JWK.new(@key)
      @claims = { "icnumber" => "01-1234567", "nonce" => "nonce-1", "iss" => "https://brunei.test/",
                  "aud" => "client-id", "sub" => "subject", "exp" => 5.minutes.from_now.to_i }
    end

    teardown { Current.reset }

    test "exchanges code and validates the signed ID token before returning the verified IC" do
      result = callback_service.call(**CALLBACK_PARAMS)

      assert_equal "01-1234567", result.value!
    end

    test "accepts the alternate IC claim and retains profile and token metadata" do
      @claims.delete("icnumber")
      @claims.merge!("ic_number" => "01-1234567", "name" => "Verified Name")
      result = callback_service.call(**CALLBACK_PARAMS)

      assert_equal ["01-1234567", "Verified Name", "Bearer"],
                   [result.value!, Current.brunei_id_claims["name"], Current.brunei_id_token_metadata["token_type"]]
    end

    test "rejects nonce issuer audience expiry and signature failures" do
      [{ "nonce" => "unexpected" }, { "iss" => "https://other.test/" }, { "aud" => "other-client" },
       { "exp" => 1.minute.ago.to_i }].each do |invalid_claims|
        result = callback_service(claims: @claims.merge(invalid_claims)).call(**CALLBACK_PARAMS)

        assert_equal "token_validation_failed", result.failure[:code]
      end
      result = callback_service(signing_key: OpenSSL::PKey::RSA.generate(2048)).call(**CALLBACK_PARAMS)

      assert_equal "token_validation_failed", result.failure[:code]
    end

    test "rejects a signed token with no verified IC claim" do
      @claims.delete("icnumber")
      result = callback_service.call(**CALLBACK_PARAMS)

      assert_equal "token_validation_failed", result.failure[:code]
    end

    test "blank callback inputs and unregistered redirects stop before token exchange" do
      client = fake_client
      service = OidcCallback.new(client:)
      invalid_params = CALLBACK_PARAMS.keys.map { |key| CALLBACK_PARAMS.merge(key => "") }
      invalid_params << CALLBACK_PARAMS.merge(redirect_uri: "https://other.test/callback")
      invalid_params.each do |params|
        result = service.call(**params)

        assert_equal ["invalid_request", 0], [result.failure[:code], client.exchanges]
      end
    end

    test "provider exchange failures preserve the invalid code contract" do
      client = fake_client
      def client.exchange_code(...) = raise(Faraday::TimeoutError)

      assert_equal OidcCallback::INVALID_CODE_ERROR, OidcCallback.new(client:).call(**CALLBACK_PARAMS).failure
    end

    test "missing client configuration preserves the configuration failure contract" do
      client = fake_client
      def client.configured? = false

      assert_equal OidcCallback::MISCONFIGURED_ERROR, OidcCallback.new(client:).call(**CALLBACK_PARAMS).failure
    end

    private

    def callback_service(claims: @claims, signing_key: @key)
      OidcCallback.new(client: fake_client(claims:, signing_key:))
    end

    def fake_client(claims: @claims, signing_key: @key)
      token = JWT.encode(claims, signing_key, "RS256", kid: @jwk.kid)
      FakeClient.new(token, @jwk.export)
    end

    class FakeClient
      attr_reader :exchanges

      def initialize(token, jwk)
        @token = token
        @jwk = jwk
        @exchanges = 0
      end

      def configured? = true
      def redirect_uri_mismatch?(uri) = uri != CALLBACK_PARAMS[:redirect_uri]
      def client_id = "client-id"

      def fetch_discovery_document
        { "token_endpoint" => "https://brunei.test/token", "jwks_uri" => "https://brunei.test/jwks",
          "issuer" => "https://brunei.test/", "id_token_signing_alg_values_supported" => ["RS256"] }
      end

      def exchange_code(_endpoint, code:, code_verifier:, redirect_uri:)
        raise ArgumentError unless [code, code_verifier,
                                    redirect_uri] == CALLBACK_PARAMS.values_at(:code, :code_verifier,
                                                                               :redirect_uri)

        @exchanges += 1
        { "id_token" => @token, "token_type" => "Bearer", "expires_in" => 300, "scope" => "openid" }
      end

      def fetched_jwks(_uri) = { "keys" => [@jwk] }
      def fetch_userinfo(...) = {}
    end
  end
end
