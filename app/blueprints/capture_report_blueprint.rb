class CaptureReportBlueprint < Blueprinter::Base
  identifier :id

  fields :capture_report_number, :manifest_id, :zone_id, :zone_area, :longitude, :latitude, :capture_report_status,
         :capture_report_remarks, :reviewed_by_id, :reviewed_at, :created_at, :updated_at

  field(:manifest_number) { |capture_report| capture_report.manifest.manifest_number }

  association :reviewed_by, blueprint: CaptureReportReviewedByBlueprint
end
