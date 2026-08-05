class RemovePositionStringFromCompaniesCrews < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :companies_crews, :position, :string
    end
  end
end
