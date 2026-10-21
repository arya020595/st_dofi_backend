class AddIsDefaultAdminToRoles < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :roles, :is_default_admin, :boolean, default: false, null: false
    add_index :roles, :company_profile_id, unique: true, where: "is_default_admin = true",
                                           algorithm: :concurrently,
                                           name: "index_roles_on_company_profile_id_and_is_default_admin"
  end
end
