class AddSmallScaleBoatFieldsToCompaniesVessels < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_table :companies_vessels, bulk: true do |t|
        t.boolean :is_powered, null: false, default: true
        t.string :charter_type # own, charter
        t.string :boat_type, null: false, default: "permanent" # permanent, temporary
        t.integer :engine_count
      end
    end
  end
end
