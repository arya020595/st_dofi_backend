class AddForeignKeyApprovedByToCompanyProfiles < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :company_profiles, :users, column: :approved_by, validate: false
  end
end
