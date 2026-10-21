class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles, id: :uuid do |t|
      t.string :reference_id, null: false # ROLE-001
      t.string :name, null: false # "Super Admin", "Officer"
      t.text :description

      t.timestamps
    end

    add_index :roles, :reference_id, unique: true
    add_index :roles, :name, unique: true
  end
end
