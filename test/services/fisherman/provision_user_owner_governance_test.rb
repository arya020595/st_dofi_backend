require "test_helper"

module Fisherman
  class ProvisionUserOwnerGovernanceTest < ActiveSupport::TestCase
    setup do
      @actor = create(:user)
      @company_profile = create(:company_profile)
    end

    test "source A derives pending approval status and Admin role from contact" do
      contact = create(:company_profile_contact, company_profile: @company_profile, designation: "Admin",
                                                 ic_no: "01-111112")

      result = ProvisionUser.call(company_profile: @company_profile,
                                  provisioning_source: ProvisionUser::DOFI_COMPANY_PROFILE,
                                  created_by: @actor,
                                  name: "Ignored",
                                  ic_number: "99-999998",
                                  company_profile_contact: contact)

      user = result.value!

      assert_equal "pending_approval", user.fisherman_status
      assert_equal ["Admin", @company_profile], [user.role.name, user.company_profile]
      assert_predicate user.role, :fisherman_admin_role?
    end

    test "source B derives claimable status for custom company role without DoFI approval" do
      role = create(:role, :fisherman, company_profile: @company_profile, name: "Crew")

      result = provision_owner_teammate(role, "01-222223")
      user = result.value!

      assert_equal "claimable", user.fisherman_status
      assert_nil user.approved_at
    end

    test "source B rejects assigning the company Admin role" do
      role = create(:role, :fisherman, company_profile: @company_profile, name: "Admin", is_default_admin: true)

      result = provision_owner_teammate(role, "01-222227")

      assert_equal :cannot_assign_admin_role, result.failure
    end

    test "source B rejects assigning the company Owner role" do
      role = create(:role, :fisherman, company_profile: @company_profile, name: "Owner", is_default: true)

      result = provision_owner_teammate(role, "01-222224")

      assert_equal :cannot_assign_owner_role, result.failure
    end

    test "source A refuses to provision a second current Owner assignment" do
      role = create(:role, :fisherman, company_profile: @company_profile, name: "Owner", is_default: true)
      create(:user, role: role, company_profile: @company_profile, ic_number: "01-222225",
                    registration_type: "Commercial", fisherman_status: "suspended")
      contact = create(:company_profile_contact, company_profile: @company_profile, designation: "Owner",
                                                 ic_no: "01-222226")

      result = ProvisionUser.call(company_profile: @company_profile,
                                  provisioning_source: ProvisionUser::DOFI_COMPANY_PROFILE,
                                  created_by: @actor,
                                  name: "Replacement",
                                  ic_number: "01-222226",
                                  company_profile_contact: contact)

      assert_equal :owner_slot_occupied, result.failure
    end

    private

    def provision_owner_teammate(role, ic_number)
      ProvisionUser.call(company_profile: @company_profile,
                         provisioning_source: ProvisionUser::FISHERMAN_OWNER,
                         created_by: @actor,
                         name: "Admin Teammate",
                         ic_number: ic_number,
                         role: role)
    end
  end
end
