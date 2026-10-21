class AddFinsGovernanceFields < ActiveRecord::Migration[8.1]
  def up
    change_table :users, bulk: true do |t|
      t.datetime :revoked_at
      t.uuid :revoked_by_id
      t.uuid :revocation_remark_id
      t.text :revocation_comment
    end

    add_index :users, :revoked_by_id
    add_index :users, :revocation_remark_id
    add_foreign_key :users, :users, column: :revoked_by_id, validate: false
    add_foreign_key :users, :approval_remarks, column: :revocation_remark_id, validate: false

    add_column :approval_remarks, :usage_scope, :string, null: false, default: "both"

    backfill_company_profile_fisherman_sources
  end

  def down
    remove_column :approval_remarks, :usage_scope

    remove_foreign_key :users, column: :revocation_remark_id
    remove_foreign_key :users, column: :revoked_by_id
    remove_index :users, :revocation_remark_id
    remove_index :users, :revoked_by_id

    change_table :users, bulk: true do |t|
      t.remove :revocation_comment
      t.remove :revocation_remark_id
      t.remove :revoked_by_id
      t.remove :revoked_at
    end
  end

  private

  def backfill_company_profile_fisherman_sources
    execute <<~SQL.squish
      UPDATE users
      SET provisioning_source = 'dofi_company_profile'
      FROM roles
      WHERE users.role_id = roles.id
        AND users.discarded_at IS NULL
        AND users.provisioning_source IS NULL
        AND roles.platform_scope = 'fisherman'
        AND (roles.is_default = TRUE OR roles.is_default_admin = TRUE)
        AND users.company_profile_id IS NOT NULL
        AND users.company_profile_contact_id IS NOT NULL
    SQL
  end
end
