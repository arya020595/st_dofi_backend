class DashboardFishingGearAnalyticsBlueprint < Blueprinter::Base
  fields :companies_fishing_gear_id, :fishing_gear_id, :name, :gear_type
  field(:total_catch_kg) { |obj| obj[:total_catch_kg].to_f.round(3) }
end
