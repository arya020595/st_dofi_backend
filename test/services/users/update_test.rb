require "test_helper"

module Users
  class UpdateTest < ActiveSupport::TestCase
    test "fisherman actor cannot assign Owner role through direct service call" do
      company_profile = create(:company_profile)
      owner_role = create(:role, :fisherman, company_profile: company_profile, name: "Owner", is_default: true)
      admin_role = create(:role, :fisherman, company_profile: company_profile, name: "Admin", is_default_admin: true)
      actor = create_active_fisherman(company_profile, admin_role, "01-630001")
      target = create(:user, role: admin_role, company_profile: company_profile, ic_number: "01-630002",
                             registration_type: "Commercial")

      result = Update.call(target, { role_id: owner_role.id },
                           assignable_roles: Role.assignable_by_fisherman(company_profile.id), actor: actor)

      assert_predicate result, :failure?
      assert_equal admin_role, target.reload.role
    end

    test "fisherman actor cannot manage Owner target through direct service call" do
      company_profile = create(:company_profile)
      owner_role = create(:role, :fisherman, company_profile: company_profile, name: "Owner", is_default: true)
      admin_role = create(:role, :fisherman, company_profile: company_profile, name: "Admin", is_default_admin: true)
      actor = create_active_fisherman(company_profile, admin_role, "01-630003")
      owner = create_active_fisherman(company_profile, owner_role, "01-630004")

      result = Update.call(owner, { role_id: admin_role.id },
                           assignable_roles: Role.assignable_by_fisherman(company_profile.id), actor: actor)

      assert_predicate result, :failure?
      assert_equal owner_role, owner.reload.role
    end

    test "updates the user status" do
      user = create(:user)

      result = Update.call(
        user,
        { status: "inactive" },
        assignable_roles: Role.none
      )

      assert_predicate result, :success?
      assert_equal "inactive", user.reload.status
    end

    test "rejects a status outside the fisherman user contract" do
      company_profile = create(:company_profile)
      role = create(:role, :fisherman, company_profile: company_profile)
      actor = create_active_fisherman(company_profile, role, "01-630005")
      user = create(:user)

      result = Update.call(
        user,
        { status: "pending" },
        assignable_roles: Role.none,
        actor: actor
      )

      assert_predicate result, :failure?
      assert_includes user.errors.attribute_names, :status
    end

    private

    def create_active_fisherman(company_profile, role, ic_number)
      timestamp = Time.current
      create(:user, role: role, company_profile: company_profile, ic_number: ic_number,
                    registration_type: "Commercial", fisherman_status: "active",
                    claimed_at: timestamp, brunei_id_verified_at: timestamp)
    end
  end
end
