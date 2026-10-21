require "test_helper"

module Roles
  class EnsureFishermanAdminRoleTest < ActiveSupport::TestCase
    test "creates a company-scoped, fisherman-platform Admin role on first call" do
      company_profile = create(:company_profile)

      role = EnsureFishermanAdminRole.call(company_profile)

      assert_equal ["Admin", company_profile], [role.name, role.company_profile]
      assert_predicate role, :fisherman_platform?
    end

    test "never grants a permission whose platform_scope column has drifted from the catalog" do
      officer_only = create(:permission, code: "roles.view")
      officer_only.update_column(:platform_scope, Permission::SHARED_PLATFORM) # rubocop:disable Rails/SkipsModelValidations
      company_profile = create(:company_profile)

      role = EnsureFishermanAdminRole.call(company_profile)

      assert_not role.permissions.include?(officer_only)
    end

    test "is idempotent — a second call for the same company returns the same role" do
      company_profile = create(:company_profile)

      first_call = EnsureFishermanAdminRole.call(company_profile)
      second_call = EnsureFishermanAdminRole.call(company_profile)

      assert_equal first_call.id, second_call.id
      assert_equal 1, Role.where(company_profile_id: company_profile.id, is_default_admin: true).count
    end
  end
end
