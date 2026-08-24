require "test_helper"

module Fisherman
  module Owners
    class RevokeAccessTest < ActiveSupport::TestCase
      test "revokes fisherman access without deleting claimed owner identity" do
        owner = create_owner("active", ic_number: "01-620001")

        result = RevokeAccess.call(user: owner, actor: create_dofi_actor, reason: "Owner replaced")

        assert_predicate result, :success?
        assert_equal "revoked", owner.reload.fisherman_status
        assert_not owner.discarded?
      end

      test "revoking claimed owner preserves claimed identity timestamps" do
        timestamp = Time.current
        owner = create_owner("active", ic_number: "01-620005", timestamp: timestamp)

        RevokeAccess.call(user: owner, actor: create_dofi_actor, reason: "Owner replaced")

        owner.reload

        assert_equal timestamp.to_i, owner.claimed_at.to_i
        assert_equal timestamp.to_i, owner.brunei_id_verified_at.to_i
        assert_not owner.current_fisherman_owner?
      end

      test "revoked owner no longer occupies the current owner slot" do
        company_profile = create(:company_profile)
        owner_role = create(:role, :fisherman, company_profile: company_profile, name: "Owner", is_default: true)
        owner = create(:user, role: owner_role, company_profile: company_profile, ic_number: "01-620002",
                              registration_type: "Commercial", fisherman_status: "claimable")

        result = RevokeAccess.call(user: owner, actor: create_dofi_actor, reason: "No longer company owner")

        assert_predicate result, :success?
        assert_nil CurrentOwnerQuery.call(company_profile)
      end

      test "rejects fisherman-side actor" do
        company_profile = create(:company_profile)
        owner_role = create(:role, :fisherman, company_profile: company_profile, name: "Owner", is_default: true)
        actor = create(:user, role: owner_role, company_profile: company_profile, ic_number: "01-620003",
                              registration_type: "Commercial")
        owner = create(:user, role: owner_role, company_profile: company_profile, ic_number: "01-620004",
                              registration_type: "Commercial", fisherman_status: "claimable")

        result = RevokeAccess.call(user: owner, actor: actor, reason: "Invalid actor")

        assert_equal :actor_not_authorized, result.failure
        assert_equal "claimable", owner.reload.fisherman_status
      end

      private

      def create_dofi_actor
        create(:user, role: create(:role, platform_scope: Role::DOFI_OFFICER_PLATFORM))
      end

      def create_owner(fisherman_status, ic_number:, timestamp: Time.current)
        company_profile = create(:company_profile)
        owner_role = create(:role, :fisherman, company_profile: company_profile, name: "Owner", is_default: true)
        create(:user, role: owner_role, company_profile: company_profile, ic_number: ic_number,
                      registration_type: "Commercial", fisherman_status: fisherman_status,
                      claimed_at: timestamp, brunei_id_verified_at: timestamp)
      end
    end
  end
end
