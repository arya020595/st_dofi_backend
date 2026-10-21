class DashboardSummaryBlueprint < Blueprinter::Base
  field(:total_catch_kg) { |obj| obj[:total_catch_kg].to_f.round(3) }
  field(:estimated_revenue) { |obj| obj[:estimated_revenue].to_f.round(2) }
  field :total_trips
  field(:catch_per_unit_effort) { |obj| obj[:catch_per_unit_effort].to_f.round(2) }
end
