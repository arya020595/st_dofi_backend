class CaptureReportExpenseBlueprint < Blueprinter::Base
  identifier :id

  fields :fuel_litres, :fuel_bnd, :ice_litres, :ice_bnd, :ration_bnd, :capture_report_id, :created_at, :updated_at
end
