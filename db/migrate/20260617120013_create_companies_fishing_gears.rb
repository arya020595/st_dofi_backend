class CreateCompaniesFishingGears < ActiveRecord::Migration[8.1]
  def change
    create_table :companies_fishing_gears, id: :uuid do |t|
      t.references :company_profile, null: false, foreign_key: true, type: :uuid
      t.references :fishing_gear, null: false, foreign_key: true, type: :uuid
      t.string :local_name # Company's local/Malay name ("Pukat Tarik", "Bubu")
      t.integer :quantity # Number of gear units owned
      t.string :approval_status, null: false, default: "pending"
      t.text :amendment_remarks
      t.references :approved_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :companies_fishing_gears, :approval_status
    add_index :companies_fishing_gears, :discarded_at
  end
end
