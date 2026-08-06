class AddFishingGearSnapshotToCompaniesFishingGears < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_table :companies_fishing_gears, bulk: true do |t|
        t.string :fishing_gear_name # Denormalized snapshot
        t.string :fishing_gear_type
        t.decimal :fishing_gear_fee, precision: 10, scale: 2
      end
    end
  end
end
