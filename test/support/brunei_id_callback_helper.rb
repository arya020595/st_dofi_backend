module BruneiIdCallbackHelper
  include Dry::Monads[:result]

  def with_brunei_id_result(result, &)
    with_brunei_id_callback(->(**) { result.call }, &)
  end

  def with_brunei_id_callback(callback)
    original = BruneiId::OidcCallback.method(:call)
    BruneiId::OidcCallback.define_singleton_method(:call) { |**params| callback.call(**params) }
    yield
  ensure
    BruneiId::OidcCallback.define_singleton_method(:call, original)
  end

  def post_brunei_id_callback(ic_number:, audience:)
    with_brunei_id_result(-> { Success(ic_number) }) do
      post "/api/v1/auth/brunei_id/callback", params: {
        code: "authorization-code", code_verifier: "pkce-verifier", nonce: "nonce",
        redirect_uri: "https://example.test/callback", audience:
      }, as: :json
    end
  end
end
