class CaptureReportDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :manifest_id, :zone_id, :zone_area, :longitude, :latitude, :capture_report_status,
         :capture_report_remarks, :reviewed_by_id, :reviewed_at, :created_at, :updated_at

  association :fish_capture_details, blueprint: FishCaptureDetailBlueprint
  association :capture_report_expense, blueprint: CaptureReportExpenseBlueprint
  association :fishing_gear_details, blueprint: FishingGearDetailBlueprint
end
