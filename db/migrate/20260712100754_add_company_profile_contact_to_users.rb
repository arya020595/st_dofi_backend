class AddCompanyProfileContactToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :company_profile_contact_id, :uuid
    add_index :users, :company_profile_contact_id, algorithm: :concurrently
    add_foreign_key :users, :company_profile_contacts, validate: false
  end
end
