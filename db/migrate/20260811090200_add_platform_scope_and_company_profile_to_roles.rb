class AddPlatformScopeAndCompanyProfileToRoles < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # PostgreSQL 11+ stores immutable constant defaults in the catalog, so this addition does not
    # rewrite the existing roles table. Strong Migrations cannot inspect a change_table block.
    safety_assured do
      change_table :roles, bulk: true do |t|
        t.string :platform_scope
        t.boolean :is_default, null: false, default: false
      end
    end

    add_reference :roles, :company_profile, type: :uuid, index: { algorithm: :concurrently }
  end
end
