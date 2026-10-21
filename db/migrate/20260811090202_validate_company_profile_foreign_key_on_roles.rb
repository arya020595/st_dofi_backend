class ValidateCompanyProfileForeignKeyOnRoles < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :roles, :company_profiles
  end
end
