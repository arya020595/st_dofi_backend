class ManifestBlueprint < Blueprinter::Base
  identifier :id

  fields :manifest_number, :fisherman_category, :manifest_status, :port_out_status, :port_in_status,
         :vessel_boat_name, :vessel_boat_no, :company_name, :capture_report_skipped, :has_minor_fishermen,
         :port_out_datetime, :port_in_datetime, :discarded_at, :created_at, :updated_at

  field(:capture_report_overview_status, &:capture_report_overview_status)
  field(:is_draft, &:draft?)
end
