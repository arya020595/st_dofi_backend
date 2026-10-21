class CreateCompaniesCaptains < ActiveRecord::Migration[8.1]
  def change
    create_table :companies_captains, id: :uuid do |t|
      t.references :company_profile, null: false, foreign_key: true, type: :uuid
      t.string :captain_name, null: false
      t.string :ic_number
      t.string :passport_number
      t.date :date_of_birth
      t.string :nationality
      t.string :approval_status, null: false, default: "pending"
      t.text :amendment_remarks
      t.references :approved_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :companies_captains, :approval_status
    add_index :companies_captains, :discarded_at
  end
end
