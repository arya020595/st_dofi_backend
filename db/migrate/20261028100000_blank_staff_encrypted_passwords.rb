# Staff (DoFi Officer-platform roles other than Jetty Manager) sign in through Active Directory and have no DoFi
# password. Devise used to force a value on every user, so existing staff rows hold an unusable bcrypt hash, and the
# seeded superadmin on an already-deployed database holds the published default one. Deploys only run db:prepare, so
# this migration clears them: encrypted_password goes back to its empty default for staff only. Jetty Managers and
# Fishermen are untouched. It is the same set of users as Role.directory_managed.
class BlankStaffEncryptedPasswords < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE users SET encrypted_password = ''
        WHERE encrypted_password <> ''
          AND role_id IN (
            SELECT id FROM roles WHERE platform_scope = 'dofi_officer' AND kind IS DISTINCT FROM 'Jetty Manager'
          )
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the cleared hashes were unusable placeholders"
  end
end
