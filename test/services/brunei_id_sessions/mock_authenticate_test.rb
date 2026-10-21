require "test_helper"

class BruneiIdSessions::MockAuthenticateTest < ActiveSupport::TestCase
  include Dry::Monads[:result]

  setup do
    @original_enabled = Rails.configuration.x.brunei_id_mock_enabled
    Rails.configuration.x.brunei_id_mock_enabled = true
  end

  teardown { Rails.configuration.x.brunei_id_mock_enabled = @original_enabled }

  test "mock authentication logs safe metadata through its distinct event" do
    entries = []
    user = User.new(id: SecureRandom.uuid)
    resolver = ->(**) { Success(kind: :dashboard, user:, ic_number: "01-123456") }
    service = BruneiIdSessions::MockAuthenticate.new(account_resolver: resolver,
                                                     logger: ->(**entry) { entries << entry })
    service.call(ic_number: "01-123456", audience: "fisherman")

    assert_equal [{ event: "brunei_id.mock_authentication", level: :info, user_id: user.id,
                    params: { audience: "fisherman", outcome: "success", kind: :dashboard, reason: nil } }], entries
  end

  test "disabled service cannot resolve or claim accounts even if called directly" do
    Rails.configuration.x.brunei_id_mock_enabled = false
    resolver = ->(**) { flunk "Disabled mock must not resolve an account" }
    service = BruneiIdSessions::MockAuthenticate.new(account_resolver: resolver)

    assert_equal :not_found, service.call(ic_number: "01-123456", audience: "fisherman").failure[:status]
  end

  test "failed unscoped claim keeps the original status-only result" do
    user = create(:user, :fins_governed_fisherman)
    service = BruneiIdSessions::MockAuthenticate.new(account_claimer: ->(**) { Failure(:already_claimed) })

    assert_equal({ kind: :mock_status, user: }, service.call(ic_number: user.ic_number).value!)
  end
end
