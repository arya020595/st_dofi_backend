class CreatePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :permissions, id: :uuid do |t|
      t.string :name, null: false
      t.string :code, null: false # e.g. "company_profiles.list"

      t.timestamps
    end

    add_index :permissions, :code, unique: true
  end
end
