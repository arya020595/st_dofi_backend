require "test_helper"
require Rails.root.join("db/migrate/20260923100000_rename_admin_accounts_to_external_users")

class RenameAdminAccountsToExternalUsersTest < ActiveSupport::TestCase
  ALL_CODES = %w[
    external_users.create external_users.deactivate external_users.delete external_users.list
    external_users.reactivate external_users.update external_users.view
  ].freeze

  test "renames admin_accounts codes in place so existing role grants survive" do
    legacy = create(:permission, code: "admin_accounts.list")
    custom_role = create(:role, permissions: [legacy])

    run_migration

    assert_equal ["external_users.list"], custom_role.reload.permissions.pluck(:code)
    assert_equal ["external_users.list", "List", "user_management", 6, 5],
                 legacy.reload.attributes.values_at("code", "name", "section", "section_order", "resource_order")
    assert_not Permission.exists?(["code LIKE ?", "admin_accounts.%"])
  end

  test "grants every external_users code to the DoFi Officer role only" do
    legacy = create(:permission, code: "admin_accounts.view")
    officer_role = create(:role, kind: Role::DOFI_OFFICER, permissions: [legacy])
    custom_role = create(:role, permissions: [create(:permission, code: "admin_accounts.deactivate")])

    run_migration

    assert_equal ALL_CODES, officer_role.reload.permissions.pluck(:code).sort
    assert_equal ["external_users.deactivate"], custom_role.reload.permissions.pluck(:code)
  end

  test "grants every external_users code even when no admin_accounts rows ever existed" do
    officer_role = create(:role, kind: Role::DOFI_OFFICER)

    run_migration

    assert_equal ALL_CODES, officer_role.reload.permissions.pluck(:code).sort
  end

  test "folds grants into an already-seeded external_users row and is idempotent" do
    legacy = create(:permission, code: "admin_accounts.reactivate")
    seeded = create(:permission, code: "external_users.reactivate")
    role = create(:role, permissions: [legacy])

    run_migration
    run_migration

    assert_equal [seeded.id], role.reload.permissions.pluck(:id)
    assert_not Permission.exists?(id: legacy.id)
    assert_equal 1, Permission.where(code: "external_users.create").count
  end

  test "down restores the admin_accounts codes and removes the new ones" do
    legacy = create(:permission, code: "admin_accounts.list")
    role = create(:role, kind: Role::DOFI_OFFICER, permissions: [legacy])
    migration = RenameAdminAccountsToExternalUsers.new

    migration.suppress_messages do
      migration.up
      migration.down
    end

    # up granted the DoFi Officer role all seven codes; down renames the four legacy ones back and drops the rest.
    assert_equal %w[admin_accounts.deactivate admin_accounts.list admin_accounts.reactivate admin_accounts.view],
                 role.reload.permissions.pluck(:code).sort
    assert_not Permission.exists?(["code LIKE ?", "external_users.%"])
  end

  private

  def run_migration
    migration = RenameAdminAccountsToExternalUsers.new
    migration.suppress_messages { migration.up }
  end
end
