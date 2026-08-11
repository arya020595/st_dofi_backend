require "test_helper"

module Roles
  class EnsureFishermanOwnerRoleTest < ActiveSupport::TestCase
    test "creates a company-scoped, default, fisherman-platform Owner role on first call" do
      company_profile = create(:company_profile)

      role = EnsureFishermanOwnerRole.call(company_profile)

      assert_equal ["Owner", company_profile], [role.name, role.company_profile]
      assert_predicate role, :fisherman_platform?
      assert_predicate role, :is_default?
    end

    test "grants every fisherman and shared permission on first call" do
      fisherman_permission = create(:permission, platform_scope: Permission::FISHERMAN_PLATFORM)
      shared_permission = create(:permission, platform_scope: Permission::SHARED_PLATFORM)
      officer_permission = create(:permission, platform_scope: Permission::DOFI_OFFICER_PLATFORM)
      company_profile = create(:company_profile)

      role = EnsureFishermanOwnerRole.call(company_profile)

      assert_includes role.permissions, fisherman_permission
      assert_includes role.permissions, shared_permission
      assert_not_includes role.permissions, officer_permission
    end

    test "is idempotent — a second call for the same company returns the same role" do
      company_profile = create(:company_profile)

      first_call = EnsureFishermanOwnerRole.call(company_profile)
      second_call = EnsureFishermanOwnerRole.call(company_profile)

      assert_equal first_call.id, second_call.id
      assert_equal 1, Role.where(company_profile_id: company_profile.id).count
    end

    test "does not reset permissions that were customized after the role was first created" do
      company_profile = create(:company_profile)
      role = EnsureFishermanOwnerRole.call(company_profile)
      role.permissions = []

      EnsureFishermanOwnerRole.call(company_profile)

      assert_empty role.reload.permissions
    end

    test "different companies each get their own Owner role" do
      first_company = create(:company_profile)
      second_company = create(:company_profile)

      first_role = EnsureFishermanOwnerRole.call(first_company)
      second_role = EnsureFishermanOwnerRole.call(second_company)

      assert_not_equal first_role.id, second_role.id
    end
  end
end
