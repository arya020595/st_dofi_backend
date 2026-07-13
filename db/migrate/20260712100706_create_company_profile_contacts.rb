class CreateCompanyProfileContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :company_profile_contacts, id: :uuid do |t|
      t.references :company_profile, null: false, foreign_key: true, type: :uuid
      t.string :full_name
      t.string :ic_no
      t.string :ic_colour
      t.string :gender
      t.string :designation
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :company_profile_contacts, :ic_no
    add_index :company_profile_contacts, :discarded_at
  end
end
