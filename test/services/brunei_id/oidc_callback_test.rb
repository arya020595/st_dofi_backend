require "test_helper"

module BruneiId
  class OidcCallbackTest < ActiveSupport::TestCase
    CALLBACK_PARAMS = {
      code: "opaque-code",
      code_verifier: "verifier",
      redirect_uri: "http://217.217.252.45:4100/general/auth/brunei-id/callback",
      nonce: "nonce-1"
    }.freeze

    test "call exchanges code, validates id token, and returns icnumber claim" do
      service = callback_service(claims: { "icnumber" => "01-1234567", "nonce" => "nonce-1" })

      result = service.call(**CALLBACK_PARAMS)

      assert_equal "01-1234567", result.value!
    end

    test "call returns token validation failure when nonce does not match" do
      service = callback_service(claims: { "icnumber" => "01-1234567", "nonce" => "unexpected" })

      result = service.call(**CALLBACK_PARAMS)

      assert_equal "token_validation_failed", result.failure[:code]
    end

    private

    def callback_service(claims:)
      OidcCallback.new(client: fake_client, token_validator: FakeTokenValidator.new(claims))
    end

    def fake_client
      FakeClient.new(
        "token_endpoint" => "https://brunei.test/token",
        "jwks_uri" => "https://brunei.test/jwks",
        "issuer" => "https://brunei.test",
        "id_token_signing_alg_values_supported" => ["RS256"]
      )
    end

    class FakeClient
      def initialize(discovery)
        @discovery = discovery
      end

      def configured? = true
      def redirect_uri_mismatch?(_redirect_uri) = false
      def client_id = "client-id"
      def fetch_discovery_document = @discovery
      def exchange_code(...) = { "id_token" => "signed-id-token" }
      def fetched_jwks(_jwks_uri) = { "keys" => [] }
      def fetch_userinfo(...) = {}
    end

    class FakeTokenValidator
      def initialize(claims)
        @claims = claims
      end

      def call(_id_token, nonce:, **)
        raise JWT::DecodeError, "Invalid nonce" unless @claims["nonce"] == nonce

        @claims
      end
    end
  end
end
