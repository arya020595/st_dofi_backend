class ValidatePositionForeignKeyOnCompaniesCrews < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :companies_crews, :positions
  end
end
