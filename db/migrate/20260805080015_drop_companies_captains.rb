class DropCompaniesCaptains < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      drop_table :companies_captains
    end
  end

  def down
    create_table :companies_captains, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.text :amendment_remarks
      t.string :approval_status, default: "pending", null: false
      t.datetime :approved_at
      t.uuid :approved_by_id
      t.string :captain_name, null: false
      t.uuid :company_profile_id, null: false
      t.date :date_of_birth
      t.datetime :discarded_at
      t.string :ic_number
      t.string :nationality
      t.string :passport_number
      t.timestamps

      t.index :approval_status
      t.index :approved_by_id
      t.index :company_profile_id
      t.index :discarded_at
    end

    add_foreign_key :companies_captains, :users, column: :approved_by_id
    add_foreign_key :companies_captains, :company_profiles
  end
end
