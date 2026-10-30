require "test_helper"

class Fisherman::AuthenticateTest < ActiveSupport::TestCase
  test "an active account passes" do
    user = fisherman(status: "active", fisherman_status: "active", **claimed)

    assert_equal user, Fisherman::Authenticate.call(verified_ic_number: user.ic_number).value!
  end

  # users.status is the company's own switch (Account Management > Assigned Users); it must hold even though
  # fisherman_status, the claim lifecycle, is active.
  test "an account its company switched to inactive is refused" do
    user = fisherman(status: "inactive", fisherman_status: "active", **claimed)

    assert_equal [:inactive, { user: user }], Fisherman::Authenticate.call(verified_ic_number: user.ic_number).failure
  end

  test "an account created inactive cannot be claimed by logging in" do
    user = fisherman(status: "inactive", fisherman_status: "claimable")

    result = Fisherman::Authenticate.call(verified_ic_number: user.ic_number)

    assert_equal [[:inactive, { user: user }], "claimable", nil],
                 [result.failure, user.reload.fisherman_status, user.claimed_at]
  end

  private

  def fisherman(**attributes)
    create(:user, :fins_governed_fisherman, **attributes)
  end

  def claimed
    timestamp = Time.current
    { claimed_at: timestamp, brunei_id_verified_at: timestamp }
  end
end
