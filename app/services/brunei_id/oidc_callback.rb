module BruneiId
  class OidcCallback
    include Dry::Monads[:result]

    INVALID_CODE_ERROR = {
      status: :unauthorized,
      code: "invalid_code",
      message: "Authorization code exchange failed."
    }.freeze
    TOKEN_VALIDATION_ERROR = {
      status: :unauthorized,
      code: "token_validation_failed",
      message: "ID token validation failed."
    }.freeze
    MISCONFIGURED_ERROR = {
      status: :internal_server_error,
      code: "brunei_id_not_configured",
      message: "BruneiID integration is not configured."
    }.freeze

    def self.call(...) = new.call(...)

    def initialize(client: OidcHttpClient.new, token_validator: OidcTokenValidator.new)
      @client = client
      @token_validator = token_validator
    end

    def call(code:, code_verifier:, redirect_uri:, nonce:)
      return Failure(invalid_request_error) if invalid_request?(code:, code_verifier:, redirect_uri:, nonce:)
      return Failure(MISCONFIGURED_ERROR) unless client.configured?

      claims = oidc_claims_for(code:, code_verifier:, redirect_uri:, nonce:)
      ic_number = claims["icnumber"].presence || claims["ic_number"].presence
      ic_number.present? ? Success(ic_number) : Failure(TOKEN_VALIDATION_ERROR)
    rescue KeyError, JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature, JSON::ParserError
      Failure(TOKEN_VALIDATION_ERROR)
    rescue Faraday::Error
      Failure(INVALID_CODE_ERROR)
    end

    private

    attr_reader :client, :token_validator

    def invalid_request?(code:, code_verifier:, redirect_uri:, nonce:)
      [code, code_verifier, redirect_uri, nonce].any?(&:blank?) || client.redirect_uri_mismatch?(redirect_uri)
    end

    def oidc_claims_for(code:, code_verifier:, redirect_uri:, nonce:)
      discovery = fetch_discovery_document
      token_response = exchange_code(discovery.fetch("token_endpoint"), code:, code_verifier:, redirect_uri:)
      store_token_response_context(token_response)
      claims = validate_id_token(token_response.fetch("id_token"), discovery:, nonce:)
      store_profile_context(claims, discovery, token_response)
      claims
    end

    def store_profile_context(claims, discovery, token_response)
      Current.brunei_id_claims = claims
      Current.brunei_id_userinfo = fetch_userinfo(discovery:, access_token: token_response["access_token"])
    end

    def validate_id_token(id_token, discovery:, nonce:)
      token_validator.call(
        id_token,
        discovery: discovery,
        nonce: nonce,
        client_id: client.client_id,
        jwks: fetched_jwks(discovery.fetch("jwks_uri"))
      )
    end

    def store_token_response_context(token_response)
      Current.brunei_id_token_response_keys = token_response.keys
      Current.brunei_id_token_metadata = token_metadata(token_response)
    end

    def token_metadata(token_response)
      return {} unless token_response.is_a?(Hash)

      token_response.slice("token_type", "expires_in", "scope")
    end

    def fetch_discovery_document = client.fetch_discovery_document
    def exchange_code(...) = client.exchange_code(...)
    def fetched_jwks(...) = client.fetched_jwks(...)
    def fetch_userinfo(...) = client.fetch_userinfo(...)

    def invalid_request_error
      {
        status: :unprocessable_content,
        code: "invalid_request",
        message: "Callback request is invalid."
      }
    end
  end
end
