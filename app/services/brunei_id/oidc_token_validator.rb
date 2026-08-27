module BruneiId
  class OidcTokenValidator
    def call(id_token, discovery:, nonce:, client_id:, jwks:)
      claims, = JWT.decode(id_token, nil, true, validation_options(discovery, client_id, jwks))
      raise JWT::DecodeError, "Invalid nonce" unless claims["nonce"] == nonce

      claims
    end

    private

    def validation_options(discovery, client_id, jwks)
      {
        algorithms: discovery.fetch("id_token_signing_alg_values_supported", ["RS256"]),
        iss: discovery.fetch("issuer"),
        verify_iss: true,
        aud: client_id,
        verify_aud: true,
        jwks: jwks
      }
    end
  end
end
