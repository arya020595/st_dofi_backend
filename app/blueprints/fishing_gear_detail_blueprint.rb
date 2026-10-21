class FishingGearDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :gear_type, :specification, :quantity, :companies_fishing_gear_id, :capture_report_id, :created_at

  field(:fishing_gear_id) { |detail| detail.companies_fishing_gear&.fishing_gear_id }
end
