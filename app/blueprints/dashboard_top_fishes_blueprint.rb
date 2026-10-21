class DashboardTopFishesBlueprint < Blueprinter::Base
  fields :dictionary_id, :local_name, :scientific_name
  field(:total_catch_kg) { |obj| obj[:total_catch_kg].to_f.round(3) }
end
