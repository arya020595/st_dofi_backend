class AddPositionForeignKeyToCompaniesCrews < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :companies_crews, :positions, validate: false
  end
end
