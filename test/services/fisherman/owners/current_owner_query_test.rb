require "test_helper"

module Fisherman
  module Owners
    class CurrentOwnerQueryTest < ActiveSupport::TestCase
      test "returns owner slot occupant using explicit slot statuses" do
        company_profile = create(:company_profile)
        owner_role = create(:role, :fisherman, company_profile: company_profile, name: "Owner", is_default: true)
        revoked_owner = create(:user, role: owner_role, company_profile: company_profile, ic_number: "01-610001",
                                      registration_type: "Commercial", fisherman_status: "revoked")
        suspended_owner = create(:user, role: owner_role, company_profile: company_profile, ic_number: "01-610002",
                                        registration_type: "Commercial", fisherman_status: "suspended")

        assert_equal suspended_owner, CurrentOwnerQuery.call(company_profile)
        assert_not revoked_owner.occupies_fisherman_owner_slot?
      end

      test "does not treat Admin as owner slot occupant" do
        company_profile = create(:company_profile)
        admin_role = create(:role, :fisherman, company_profile: company_profile, name: "Admin",
                                               is_default_admin: true)
        create(:user, role: admin_role, company_profile: company_profile, ic_number: "01-610003",
                      registration_type: "Commercial", fisherman_status: "active",
                      claimed_at: Time.current, brunei_id_verified_at: Time.current)

        assert_nil CurrentOwnerQuery.call(company_profile)
      end
    end
  end
end
