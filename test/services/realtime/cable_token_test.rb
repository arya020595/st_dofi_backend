require "test_helper"

class Realtime::CableTokenTest < ActiveSupport::TestCase
  test "issue produces a token that resolves to the same current user" do
    user = create(:user)

    payload = Realtime::CableToken.issue(user)

    assert_equal user, Realtime::CableToken.user_for(payload.fetch(:realtime_token))
  end

  test "a token no longer resolves after the user's JWT identifier changes" do
    user = create(:user)
    token = Realtime::CableToken.issue(user).fetch(:realtime_token)
    user.update!(jti: SecureRandom.uuid)

    assert_nil Realtime::CableToken.user_for(token)
  end
end
