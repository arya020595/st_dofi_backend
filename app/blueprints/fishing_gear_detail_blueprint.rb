class FishingGearDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :gear_type, :specification, :quantity, :companies_fishing_gear_id, :capture_report_id, :created_at
end
