PERMISSION_GROUPS = {
  "dashboard" => %w[view],
  "manifest_list" => %w[view list update delete],
  "manifest_form" => %w[view create],
  "manifest_approvals" => %w[view list approve amendment],
  "profiling" => %w[view list create update delete],
  "dictionaries" => %w[view list create update delete],
  "ports" => %w[view list create update delete],
  "zones" => %w[view list create update delete],
  "fishing_gears" => %w[view list create update delete],
  "nationalities" => %w[view list create update delete],
  "positions" => %w[view list create update delete],
  "roles" => %w[view list create update delete],
  "dofi_officer_users" => %w[view list create update delete],
  "fisherman_approvals" => %w[view list approve amendment],
  "jetty_manager_approvals" => %w[view list approve amendment],
  "skip_reasons" => %w[view list create update delete],
  "approval_remarks" => %w[view list create update delete],
  "companies_vessels" => %w[view list create update delete],
  "companies_vessel_approvals" => %w[view list approve amendment],
  "companies_crews" => %w[view list create update delete],
  "companies_crew_approvals" => %w[view list approve amendment],
  "companies_fishing_gears" => %w[view list create update delete],
  "companies_fishing_gear_approvals" => %w[view list approve amendment],
  "companies_documents" => %w[view list create update],
  "companies_document_approvals" => %w[view list approve amendment],
  "capture_reports" => %w[view list create update],
  "capture_report_verifications" => %w[view list verify amendment],
  "manifest_minor_fishermen" => %w[view create delete],
  "manifest_expenses" => %w[view create update]
}.freeze

PERMISSION_GROUPS.each do |resource, actions|
  actions.each do |action|
    code = "#{resource}.#{action}"
    Permission.find_or_create_by!(code: code) do |permission|
      permission.name = "#{resource.humanize} - #{action.humanize}"
    end
  end
end

puts "Seeded #{Permission.count} permissions"
