class CreatePermissionRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :permission_roles, id: :uuid do |t|
      t.references :role,       null: false, foreign_key: true, type: :uuid
      t.references :permission, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :permission_roles, %i[role_id permission_id],
              unique: true,
              name: "index_permission_roles_on_role_id_and_permission_id"
  end
end
