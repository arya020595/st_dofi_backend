class AddVesselAndUsageValueToCompaniesFishingGears < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      add_reference :companies_fishing_gears, :companies_vessel, type: :uuid, foreign_key: true

      # The length (in meters) or count the fisherman is declaring for THIS gear on THIS vessel,
      # whichever FishingGear#unit calls for — distinct from the pre-existing `quantity` column, which
      # is the number of physical gear units the company owns overall. Kept as one decimal column
      # rather than two nullable ones since a given gear only ever uses one unit at a time.
      add_column :companies_fishing_gears, :usage_value, :decimal, precision: 10, scale: 2
    end
  end
end
