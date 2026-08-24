module BruneiId
  class OidcHttpClient
    def configured?
      [base_url, client_id, client_secret].all?(&:present?)
    end

    def redirect_uri_mismatch?(redirect_uri)
      configured_redirect_uri.present? && redirect_uri != configured_redirect_uri
    end

    def fetch_discovery_document
      request(method: :get, url: discovery_url, endpoint: "discovery")
    end

    def exchange_code(token_endpoint, code:, code_verifier:, redirect_uri:)
      request(method: :post, url: token_endpoint, endpoint: "token", body: token_request_body(code, code_verifier,
                                                                                              redirect_uri))
    end

    def fetched_jwks(jwks_uri)
      request(method: :get, url: jwks_uri, endpoint: "jwks")
    end

    def fetch_userinfo(discovery:, access_token:)
      userinfo_endpoint = discovery["userinfo_endpoint"]
      return {} if userinfo_endpoint.blank? || access_token.blank?

      request(method: :get, url: userinfo_endpoint, endpoint: "userinfo", headers: bearer_headers(access_token))
    rescue Faraday::Error
      {}
    end

    def client_id
      env("BRUNEIID_CLIENT_ID")
    end

    private

    def request(attributes)
      OidcHttpRequest.new(connection: connection, attributes: attributes).call
    end

    def token_request_body(code, code_verifier, redirect_uri)
      {
        grant_type: "authorization_code",
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        code_verifier: code_verifier
      }
    end

    def bearer_headers(access_token)
      { "Authorization" => "Bearer #{access_token}" }
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

    def base_url
      env("BRUNEIID_BASE_URL")
    end

    def client_secret
      env("BRUNEIID_CLIENT_SECRET")
    end

    def configured_redirect_uri
      env("BRUNEIID_REDIRECT_URI")
    end

    def env(key)
      ENV.fetch(key, nil)
    end
  end
end
