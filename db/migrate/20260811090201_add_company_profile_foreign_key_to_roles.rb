class AddCompanyProfileForeignKeyToRoles < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :roles, :company_profiles, validate: false
  end
end
