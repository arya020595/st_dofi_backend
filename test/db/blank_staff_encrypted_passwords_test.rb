require "test_helper"
require Rails.root.join("db/migrate/20261028100000_blank_staff_encrypted_passwords")

class BlankStaffEncryptedPasswordsTest < ActiveSupport::TestCase
  test "clears the stored password of staff, custom DoFi roles included, and nothing else" do
    staff = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER))
    custom = create(:user, role: create(:role, name: "Inspector"))
    jetty = create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER))
    fisherman = create(:user, :fins_governed_fisherman)
    no_role = create(:user, role: nil)

    run_migration

    cleared = [staff, custom, jetty, fisherman, no_role].map { it.reload.encrypted_password.empty? }

    assert_equal [true, true, false, false, false], cleared
  end

  test "cannot be reversed" do
    assert_raises(ActiveRecord::IrreversibleMigration) { BlankStaffEncryptedPasswords.new.down }
  end

  def run_migration
    migration = BlankStaffEncryptedPasswords.new
    migration.suppress_messages { migration.up }
  end
end
