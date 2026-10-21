class ValidateForeignKeyCompanyProfileContactOnUsers < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :users, :company_profile_contacts
  end
end
