class CaptureReportDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :manifest_id, :zone_id, :zone_area, :longitude, :latitude, :capture_report_status,
         :capture_report_remarks, :reviewed_by_id, :reviewed_at, :created_at, :updated_at

  association :reviewed_by, blueprint: CaptureReportReviewedByBlueprint
  association :fish_capture_details, blueprint: FishCaptureDetailBlueprint
  association :fishing_gear_details, blueprint: FishingGearDetailBlueprint
end
