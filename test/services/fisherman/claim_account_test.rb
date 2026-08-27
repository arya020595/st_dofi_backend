require "test_helper"

module Fisherman
  # rubocop:disable Minitest/MultipleAssertions
  class ClaimAccountTest < ActiveSupport::TestCase
    setup do
      @company_profile = create(:company_profile)
      @role = create(:role, :fisherman, company_profile: @company_profile)
    end

    test "claimable user becomes active when verified IC matches inside the lock" do
      user = create(:user, role: @role, company_profile: @company_profile, ic_number: "01-555555",
                           registration_type: "Commercial", fisherman_status: "claimable")

      result = ClaimAccount.call(user: user, verified_ic_number: "01555555", verified_at: Time.current)

      assert_predicate result, :success?
      assert_equal "active", user.reload.fisherman_status
      assert_predicate user, :claimed_at?
      assert_predicate user, :brunei_id_verified_at?
    end

    test "ic mismatch fails without claiming" do
      user = create(:user, role: @role, company_profile: @company_profile, ic_number: "01-666666",
                           registration_type: "Commercial", fisherman_status: "claimable")

      result = ClaimAccount.call(user: user, verified_ic_number: "01-000000", verified_at: Time.current)

      assert_equal :ic_mismatch, result.failure
      assert_nil user.reload.claimed_at
      assert_equal "claimable", user.fisherman_status
    end

    test "already claimed fails safely" do
      timestamp = Time.current
      user = create(:user, role: @role, company_profile: @company_profile, ic_number: "01-777777",
                           registration_type: "Commercial", fisherman_status: "claimable",
                           claimed_at: timestamp)

      result = ClaimAccount.call(user: user, verified_ic_number: "01-777777", verified_at: Time.current)

      assert_equal :already_claimed, result.failure
    end
  end
  # rubocop:enable Minitest/MultipleAssertions
end
