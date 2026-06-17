class CreateCompaniesVessels < ActiveRecord::Migration[8.1]
  def change
    create_table :companies_vessels, id: :uuid do |t|
      t.references :company_profile, null: false, foreign_key: true, type: :uuid
      t.string :vessel_name, null: false
      t.string :boat_number, null: false # BN 6767 BY
      t.date :license_reg_date # "License Reg. Date" shown in vessel table
      t.date :license_expiry_date
      t.integer :capacity
      t.string :approval_status, null: false, default: "pending" # AASM: pending, approved, amendment_required
      t.text :amendment_remarks
      t.references :approved_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :companies_vessels, :boat_number
    add_index :companies_vessels, :approval_status
    add_index :companies_vessels, :discarded_at
  end
end
