class ValidateForeignKeyApprovedByOnCompanyProfiles < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :company_profiles, :users
  end
end
