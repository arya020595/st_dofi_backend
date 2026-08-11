class ManifestDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :manifest_number, :fisherman_category, :manifest_status, :port_out_status, :port_in_status,
         :vessel_boat_name, :vessel_boat_no, :captain_name, :captain_ic_number, :company_name,
         :port_out_area, :port_out_name, :port_out_datetime, :port_in_area, :port_in_name, :port_in_datetime,
         :zone_area, :longitude, :latitude, :capture_report_skipped, :skip_reason_name, :skip_reason_remarks,
         :has_minor_fishermen, :companies_vessel_id, :captain_crew_id, :company_profile_id, :port_out_id,
         :port_in_id, :zone_id, :skip_reason_id, :ais_tracking, :has_support_vessel, :support_vessel_id,
         :support_vessel_name, :support_vessel_no, :port_out_amendment_remarks, :port_in_amendment_remarks,
         :capture_report_amendment_remarks, :discarded_at, :created_at, :updated_at

  field(:capture_report_overview_status, &:capture_report_overview_status)
  field(:is_draft, &:draft?)

  association :crew_manifests, blueprint: CrewManifestBlueprint
  association :manifest_minor_fishermen, blueprint: ManifestMinorFishermanBlueprint
  association :capture_reports, blueprint: CaptureReportDetailBlueprint
  association :manifest_histories, blueprint: ManifestHistoryBlueprint
  association :manifest_expense, blueprint: ManifestExpenseBlueprint
end
