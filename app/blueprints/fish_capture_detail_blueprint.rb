class FishCaptureDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :dictionary_id, :local_name, :scientific_name, :fish_type, :price_per_kg, :amount_captured_kg,
         :overall_total, :synced_at, :capture_report_id, :fishing_gear_detail_id, :created_at, :updated_at
end
