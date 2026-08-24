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
  "fisherman_approvals" => %w[view list approve reject deactivate reactivate revoke amendment],
  "jetty_manager_approvals" => %w[view list approve reject deactivate reactivate revoke amendment],
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
  "manifest_expenses" => %w[view create update],
  # Fisherman-platform equivalents of "roles"/"dofi_officer_users" above — a company's own
  # self-management of its users/roles, entirely separate from DoFi Officer's admin-wide ones.
  "fisherman_users" => %w[view list create update delete],
  "fisherman_roles" => %w[view list create update delete]
}.freeze

# Every resource group above is either entirely one platform's, or "shared" (used identically by
# both platforms — e.g. companies_crews.create, checked by both a fisherman's own self-service form
# and an officer profiling on their behalf via the same dual-mounted controller). A handful of
# groups are shared for most actions but keep one specific action DoFi-Officer-only:
#   - ports/zones/fishing_gears/nationalities/positions: browsing (view/list) is shared with the
#     Fisherman app's own pickers; curating the master data itself (create/update/delete) is
#     DoFi-Officer-only.
#   - profiling (CompanyProfilePolicy): view/create/update are shared (a fisherman manages their own
#     company profile), but destroy is DoFi-Officer-only — a company must never be able to delete
#     its own profile record via a broad permission grant.
#   - manifest_list (ManifestPolicy#update?): the generic admin-side manifest update action, checked
#     by ManifestPolicy#update? — deliberately distinct from the fisherman-side
#     ManifestPolicy#fisherman_update?, which checks manifest_form.create instead. Fisherman roles
#     must never get manifest_list.update.
DOFI_OFFICER_ONLY_GROUPS = %w[
  dictionaries roles dofi_officer_users fisherman_approvals jetty_manager_approvals
  approval_remarks manifest_approvals companies_vessel_approvals companies_crew_approvals
  companies_fishing_gear_approvals companies_document_approvals capture_report_verifications
].freeze
FISHERMAN_ONLY_GROUPS = %w[fisherman_users fisherman_roles].freeze
DOFI_OFFICER_ONLY_ACTIONS = {
  "ports" => %w[create update delete],
  "zones" => %w[create update delete],
  "fishing_gears" => %w[create update delete],
  "nationalities" => %w[create update delete],
  "positions" => %w[create update delete],
  "skip_reasons" => %w[create update delete],
  "profiling" => %w[delete],
  "manifest_list" => %w[update]
}.freeze

def platform_scope_for(resource, action)
  return Permission::FISHERMAN_PLATFORM if FISHERMAN_ONLY_GROUPS.include?(resource)
  return Permission::DOFI_OFFICER_PLATFORM if DOFI_OFFICER_ONLY_GROUPS.include?(resource)
  return Permission::DOFI_OFFICER_PLATFORM if DOFI_OFFICER_ONLY_ACTIONS[resource]&.include?(action)

  Permission::SHARED_PLATFORM
end

PERMISSION_GROUPS.each do |resource, actions|
  actions.each do |action|
    code = "#{resource}.#{action}"
    platform_scope = platform_scope_for(resource, action)

    permission = Permission.find_or_create_by!(code: code) do |record|
      record.name = "#{resource.humanize} - #{action.humanize}"
      record.platform_scope = platform_scope
    end
    permission.update!(platform_scope: platform_scope) if permission.platform_scope != platform_scope
  end
end

puts "Seeded #{Permission.count} permissions"
