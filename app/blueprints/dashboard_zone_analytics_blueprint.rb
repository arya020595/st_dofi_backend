class DashboardZoneAnalyticsBlueprint < Blueprinter::Base
  fields :zone_id, :zone_area
  field(:total_catch_kg) { |obj| obj[:total_catch_kg].to_f.round(3) }
end
