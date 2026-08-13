module BruneiId
  # rubocop:disable Metrics/ClassLength
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

    def call(code:, code_verifier:, redirect_uri:, nonce:)
      return Failure(invalid_request_error) if invalid_request?(code:, code_verifier:, redirect_uri:, nonce:)
      return Failure(MISCONFIGURED_ERROR) unless configured?

      claims = oidc_claims_for(code:, code_verifier:, redirect_uri:, nonce:)

      ic_number = claims["icnumber"].presence || claims["ic_number"].presence
      return Failure(TOKEN_VALIDATION_ERROR) if ic_number.blank?

      Success(ic_number)
    rescue KeyError, JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature, JSON::ParserError
      Failure(TOKEN_VALIDATION_ERROR)
    rescue Faraday::Error
      Failure(INVALID_CODE_ERROR)
    end

    private

    def invalid_request?(code:, code_verifier:, redirect_uri:, nonce:)
      [code, code_verifier, redirect_uri, nonce].any?(&:blank?) || redirect_uri_mismatch?(redirect_uri)
    end

    def configured?
      [base_url, client_id, client_secret].all?(&:present?)
    end

    def oidc_claims_for(code:, code_verifier:, redirect_uri:, nonce:)
      discovery = fetch_discovery_document
      token_response = exchange_code(discovery.fetch("token_endpoint"), code:, code_verifier:, redirect_uri:)
      store_token_response_context(token_response)

      claims = validate_id_token(token_response.fetch("id_token"), discovery:, nonce:)
      Current.brunei_id_claims = claims
      Current.brunei_id_userinfo = fetch_userinfo(discovery:, access_token: token_response["access_token"])
      claims
    end

    def fetch_discovery_document
      perform_request(method: :get, url: discovery_url, endpoint: "discovery")
    end

    # rubocop:disable Metrics/MethodLength
    def exchange_code(token_endpoint, code:, code_verifier:, redirect_uri:)
      perform_request(
        method: :post,
        url: token_endpoint,
        endpoint: "token",
        body: {
          grant_type: "authorization_code",
          code:,
          client_id:,
          client_secret:,
          redirect_uri:,
          code_verifier:
        }
      )
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def validate_id_token(id_token, discovery:, nonce:)
      claims, = JWT.decode(
        id_token,
        nil,
        true,
        algorithms: discovery.fetch("id_token_signing_alg_values_supported", ["RS256"]),
        iss: discovery.fetch("issuer"),
        verify_iss: true,
        aud: client_id,
        verify_aud: true,
        jwks: fetched_jwks(discovery.fetch("jwks_uri"))
      )

      raise JWT::DecodeError, "Invalid nonce" unless claims["nonce"] == nonce

      claims
    end
    # rubocop:enable Metrics/MethodLength

    def fetched_jwks(jwks_uri)
      perform_request(method: :get, url: jwks_uri, endpoint: "jwks")
    end

    def fetch_userinfo(discovery:, access_token:)
      userinfo_endpoint = discovery["userinfo_endpoint"]
      return {} if userinfo_endpoint.blank? || access_token.blank?

      perform_request(
        method: :get,
        url: userinfo_endpoint,
        endpoint: "userinfo",
        headers: { "Authorization" => "Bearer #{access_token}" }
      )
    rescue Faraday::Error
      {}
    end

    def parse_json(body)
      JSON.parse(body)
    end

    def discovery_url
      URI.join(base_url, "/.well-known/openid-configuration").to_s
    end

    def connection
      @connection ||= Faraday.new do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def perform_request(method:, url:, endpoint:, body: nil, headers: {})
      response = connection.public_send(method, url) do |request|
        headers.each { |key, value| request.headers[key] = value }
        if body.present?
          request.headers["Content-Type"] = "application/x-www-form-urlencoded"
          request.body = body
        end
      end

      parsed_body = parse_response_body(response.body)
      log_outbound_request(method:, url:, request_body: body, response_body: parsed_body, status_code: response.status)
      raise Faraday::BadRequestError unless response.success?

      parsed_body
    rescue Faraday::Error => e
      log_outbound_request(
        method:,
        url:,
        request_body: body,
        response_body: parse_response_body(e.response&.dig(:body)),
        status_code: e.response&.dig(:status),
        exception: e
      )
      raise
    ensure
      log_token_exchange_summary(parsed_body, endpoint) if endpoint == "token" && response&.success?
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    # rubocop:disable Metrics/ParameterLists
    def log_outbound_request(method:, url:, request_body:, response_body:, status_code:, exception: nil)
      ApiRequestLogs::Recorder.log_outbound(provider: "brunei_id", method:, url:, request_body:, response_body:,
                                            status_code:, exception:)
    end
    # rubocop:enable Metrics/ParameterLists

    def parse_response_body(body)
      parse_json(body)
    rescue JSON::ParserError
      { raw_body: body }
    end

    def log_token_exchange_summary(response_body, endpoint)
      return unless endpoint == "token"

      Rails.logger.info(
        {
          provider: "brunei_id",
          token_exchange_success: true,
          token_response_keys: response_body.is_a?(Hash) ? response_body.keys : []
        }.to_json
      )
    end

    def token_metadata(token_response)
      return {} unless token_response.is_a?(Hash)

      token_response.slice("token_type", "expires_in", "scope")
    end

    def public_token_response(token_response)
      return {} unless token_response.is_a?(Hash)

      token_response.except("access_token", "id_token", "refresh_token")
    end

    def store_token_response_context(token_response)
      Current.brunei_id_token_response_keys = token_response.keys
      Current.brunei_id_token_metadata = token_metadata(token_response)
      Current.brunei_id_token_response = public_token_response(token_response)
      Current.brunei_id_decoded_tokens = decoded_tokens(token_response)
    end

    def decoded_tokens(token_response)
      return {} unless token_response.is_a?(Hash)

      {
        access_token: decode_token(token_response["access_token"]),
        id_token: decode_token(token_response["id_token"])
      }.compact
    end

    def decode_token(token)
      return if token.blank?

      segments = token.to_s.split(".")
      return { format: "opaque" } unless segments.length >= 2

      jwt_payload(segments)
    end

    def decode_jwt_segment(segment)
      padded = segment.to_s
      padding = (4 - (padded.length % 4)) % 4
      padded = "#{padded}#{'=' * padding}"

      JSON.parse(Base64.urlsafe_decode64(padded))
    rescue ArgumentError, JSON::ParserError
      nil
    end

    def jwt_payload(segments)
      header = decode_jwt_segment(segments[0])
      payload = decode_jwt_segment(segments[1])
      return { format: "opaque" } if header.nil? || payload.nil?

      { format: "jwt", header: header, payload: payload }
    end

    def base_url
      env("BRUNEIID_BASE_URL")
    end

    def client_id
      env("BRUNEIID_CLIENT_ID")
    end

    def client_secret
      env("BRUNEIID_CLIENT_SECRET")
    end

    def configured_redirect_uri
      env("BRUNEIID_REDIRECT_URI")
    end

    def redirect_uri_mismatch?(redirect_uri)
      configured_redirect_uri.present? && redirect_uri != configured_redirect_uri
    end

    def invalid_request_error
      {
        status: :unprocessable_content,
        code: "invalid_request",
        message: "Callback request is invalid."
      }
    end

    def env(key)
      ENV.fetch(key, nil)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
