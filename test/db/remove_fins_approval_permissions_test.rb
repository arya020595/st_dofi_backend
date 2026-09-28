require "test_helper"
require Rails.root.join("db/migrate/20260928100000_remove_fins_approval_permissions")

class RemoveFinsApprovalPermissionsTest < ActiveSupport::TestCase
  test "deletes every FINS Approval code and its grants, leaving other codes untouched" do
    codes = %w[fisherman_approvals.approve jetty_manager_approvals.revoke approval_remarks.list]
    removed = codes.map { |code| create(:permission, code: code) }
    kept = create(:permission, code: "external_users.list")
    role = create(:role, kind: Role::DOFI_OFFICER, permissions: removed + [kept])

    run_migration

    assert_equal ["external_users.list"], role.reload.permissions.pluck(:code)
    assert_not Permission.exists?(id: removed.map(&:id))
    assert_not PermissionRole.exists?(permission_id: removed.map(&:id))
  end

  test "is idempotent" do
    create(:permission, code: "fisherman_approvals.list")

    run_migration
    run_migration

    assert_not Permission.exists?(["code LIKE ?", "fisherman_approvals.%"])
  end

  test "down restores the codes and grants them to the DoFi Officer role only" do
    officer_role = create(:role, kind: Role::DOFI_OFFICER)
    custom_role = create(:role)
    migration = RemoveFinsApprovalPermissions.new

    migration.suppress_messages do
      migration.up
      migration.down
    end

    assert_equal 19, officer_role.reload.permissions.count
    assert_includes officer_role.permissions.pluck(:code), "jetty_manager_approvals.approve"
    assert_empty custom_role.reload.permissions
  end

  private

  def run_migration
    migration = RemoveFinsApprovalPermissions.new
    migration.suppress_messages { migration.up }
  end
end
