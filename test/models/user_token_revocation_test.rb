require "test_helper"

# When a user's tokens are revoked: the JTI (JTIMatcher's `jti` column, which every issued JWT carries) is replaced.
class UserTokenRevocationTest < ActiveSupport::TestCase
  setup do
    @staff = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER), username: "mprt/azri.nizam")
    @jetty = create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER))
    @fisherman = create(:user, :fins_governed_fisherman, fisherman_status: "active", claimed_at: Time.current,
                                                         brunei_id_verified_at: Time.current)
  end

  # Runs the change and says whether it replaced the user's JTI.
  def rotates?(user)
    before = user.reload.jti
    yield user
    user.reload.jti != before
  end

  test "a new user gets one JTI and is not rotated again on create" do
    user = build(:user, :officer_shaped, role: @staff.role)

    assert_nil user.jti
    user.save!

    assert_predicate user.jti, :present?
    assert_equal user.jti, user.reload.jti
  end

  test "moving to inactive, suspended or revoked rotates the JTI, for every kind of user" do
    revoked_fisherman = create(:user, :fins_governed_fisherman, fisherman_status: "active", claimed_at: Time.current,
                                                                brunei_id_verified_at: Time.current)
    suspended_staff = create(:user, :officer_shaped, role: @staff.role)
    results = [rotates?(@staff, &:deactivate!), rotates?(suspended_staff, &:suspend!), rotates?(@jetty, &:deactivate!),
               rotates?(@fisherman, &:suspend_fisherman!), rotates?(revoked_fisherman, &:revoke_fisherman!)]

    assert_equal [true] * 5, results
  end

  test "a direct status write and a discard rotate the JTI" do
    assert rotates?(@staff) { |user| user.update!(status: "inactive") }
    assert rotates?(@jetty, &:discard)
    assert rotates?(@fisherman, &:discard)
  end

  test "re-enabling does not bring the old JTI back, and does not rotate again" do
    issued = @staff.jti
    @staff.deactivate!

    assert_not rotates?(@staff, &:reactivate!)
    assert_not_equal issued, @staff.reload.jti
  end

  test "undiscarding does not rotate or restore the old JTI" do
    @staff.discard
    revoked = @staff.reload.jti

    assert_not rotates?(@staff, &:undiscard)
    assert_equal revoked, @staff.reload.jti
  end

  test "changing the username (the sign-in identity) rotates the JTI" do
    assert rotates?(@staff) { |user| user.update!(username: "mprt/another.name") }
    assert rotates?(@jetty) { |user| user.update!(username: "mprt/jetty.two") }
  end

  test "ordinary profile edits never rotate the JTI" do
    edit = lambda do |user|
      user.update!(name: "Renamed", position: "Inspector", unit: "Block B", contact_no: "+6738123456",
                   email: "azri@example.test", preferred_locale: "ms", designation: "Senior")
    end

    assert_not rotates?(@staff, &edit)
  end

  test "saving an unchanged status or username never rotates the JTI" do
    assert_not rotates?(@staff) { |user| user.update!(status: "active", username: "MPRT/Azri.Nizam") }
    assert_not rotates?(@fisherman) { |user| user.update!(fisherman_status: "active") }
  end

  test "claimable Fishermen, who have never held a token, are not blocked" do
    claimable = create(:user, :fins_governed_fisherman)

    assert_predicate claimable, :active_for_authentication?
  end

  test "inactive, suspended, revoked and discarded users are refused authentication" do
    refused = [@staff.tap(&:deactivate!), @jetty.tap(&:discard), @fisherman.tap(&:revoke_fisherman!)]

    assert_equal [false] * 3, refused.map(&:active_for_authentication?)
    assert_equal [:invalid] * 3, refused.map(&:inactive_message)
  end
end
