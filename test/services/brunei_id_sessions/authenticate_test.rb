require "test_helper"

class BruneiIdSessions::AuthenticateTest < ActiveSupport::TestCase
  include Dry::Monads[:result]

  test "claim failures and unknown fisherman failures retain the same response" do
    %i[not_claimable already_claimed ic_mismatch unexpected].each do |reason|
      verifier = ->(**) { Success("01-123456") }
      authenticator = ->(**) { Failure(reason) }
      resolver = BruneiIdSessions::ResolveAccount.new(fisherman_authenticator: authenticator)
      service = BruneiIdSessions::Authenticate.new(oidc_callback: verifier, account_resolver: resolver)

      result = service.call(audience: "fisherman", code: "code")

      assert_equal({ status: :unprocessable_content, code: "fisherman_claim_failed",
                     message: "Fisherman account could not be claimed.", kind: :claim_failed, ic_number: "01-123456" },
                   result.failure)
    end
  end

  test "provider failures log only their safe outcome and preserve the failure contract" do
    entries = []
    error = BruneiId::OidcCallback::INVALID_CODE_ERROR
    service = BruneiIdSessions::Authenticate.new(oidc_callback: ->(**) { Failure(error) },
                                                 logger: ->(**entry) { entries << entry })
    result = service.call(audience: "fisherman", code: "secret-code", code_verifier: "secret-verifier")

    assert_equal [error, [{ event: "brunei_id.authentication", level: :warn, user_id: nil,
                            params: { audience: "fisherman", outcome: "failure", reason: "invalid_code" } }]],
                 [result.failure, entries]
  end
end
