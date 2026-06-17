class CreateCompaniesCrews < ActiveRecord::Migration[8.1]
  def change
    create_table :companies_crews, id: :uuid do |t|
      t.references :company_profile, null: false, foreign_key: true, type: :uuid
      t.string :crew_name, null: false
      t.date :date_of_birth # D.O.B column in crew table
      t.string :ic_number # IC No. for locals
      t.string :passport_number # Passport No. for foreign crew
      t.string :position # "Captain", "Staff Crew"
      t.string :nationality # "Bruneian", "Malaysian", "Chinese"
      t.string :approval_status, null: false, default: "pending"
      t.text :amendment_remarks
      t.references :approved_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :companies_crews, :approval_status
    add_index :companies_crews, :discarded_at
  end
end
