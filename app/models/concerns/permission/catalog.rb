module Permission::Catalog
  # Canonical source for permission codes, role-editor grouping, and platform assignment.
  SECTIONS = [
    { key: "dashboard", label: "Dashboard", resources: [
      { key: "dashboard", label: "Dashboard", shared: %w[list] }
    ] },
    { key: "manifest", label: "Manifest", resources: [
      { key: "manifests", label: "Manifests",
        fisherman: %w[list view create update delete offline_bundle submit_port_out resubmit_port_out submit_port_in
                      resubmit_port_in skip_capture_report] },
      { key: "manifest_approvals", label: "Manifest Approvals",
        dofi_officer: %w[list view approve_port_out request_amendment_port_out approve_port_in
                         request_amendment_port_in] },
      { key: "capture_reports", label: "Capture Reports", fisherman: %w[list view create update resubmit] },
      { key: "capture_report_verifications", label: "Capture Report Verifications",
        dofi_officer: %w[list view verify request_amendment] },
      { key: "manifest_minor_fishermen", label: "Minor Fishermen", fisherman: %w[list view create delete] },
      { key: "manifest_expenses", label: "Manifest Expenses", fisherman: %w[view create update] }
    ] },
    { key: "profiling", label: "Profiling", resources: [
      { key: "company_profiles", label: "Company Profiles",
        dofi_officer: %w[list view create update delete] },
      { key: "company_profile_contacts", label: "Company Profile Contacts",
        dofi_officer: %w[create update delete] }
    ] },
    { key: "dictionary", label: "Dictionary", resources: [
      { key: "dictionaries", label: "Dictionaries", dofi_officer: %w[list view create update delete] },
      { key: "dictionary_groups", label: "Dictionary Groups", dofi_officer: %w[list view create update delete] },
      { key: "dictionary_families", label: "Dictionary Families", dofi_officer: %w[list view create update delete] }
    ] },
    { key: "master_data", label: "Master Data", resources: [
      { key: "ports", label: "Ports", dofi_officer: %w[list view create update delete] },
      { key: "zones", label: "Zones", dofi_officer: %w[list view create update delete] },
      { key: "fishing_gears", label: "Fishing Gears", dofi_officer: %w[list view create update delete] },
      { key: "nationalities", label: "Nationalities", dofi_officer: %w[list view create update delete] },
      { key: "positions", label: "Positions", dofi_officer: %w[list view create update delete] },
      { key: "skip_reasons", label: "Reasons", dofi_officer: %w[list view create update delete] }
    ] },
    { key: "user_management", label: "User Management", resources: [
      { key: "roles", label: "Roles", dofi_officer: %w[list view create update delete] },
      { key: "dofi_officer_users", label: "DoFi Officer Users", dofi_officer: %w[list view create update delete] },
      { key: "permissions", label: "Permissions", shared: %w[list] },
      { key: "entity_users", label: "Entity Users", dofi_officer: %w[list] }
    ] },
    { key: "account_management", label: "Account Management", resources: [
      { key: "fisherman_users", label: "Users", fisherman: %w[list view create update delete] },
      { key: "fisherman_roles", label: "Roles", fisherman: %w[list view create update delete] }
    ] },
    { key: "fins_approval", label: "FINS Approval", resources: [
      { key: "fisherman_approvals", label: "Fisherman Approval",
        dofi_officer: %w[list view approve reject deactivate reactivate revoke] },
      { key: "jetty_manager_approvals", label: "Jetty Manager Approval",
        dofi_officer: %w[list view approve reject deactivate reactivate revoke] },
      { key: "approval_remarks", label: "Approval Request",
        dofi_officer: %w[list view create update delete] },
      { key: "admin_accounts", label: "Admin Accounts", dofi_officer: %w[list view deactivate reactivate] }
    ] },
    { key: "companies", label: "Companies", resources: [
      { key: "companies_vessels", label: "Vessels & Fishing Gears",
        fisherman: %w[list view create update delete images] },
      { key: "companies_vessel_approvals", label: "Vessel & Fishing Gear Approvals",
        dofi_officer: %w[list view approve request_amendment] },
      { key: "companies_crews", label: "Crews", fisherman: %w[list view create update delete] },
      { key: "companies_crew_approvals", label: "Crew Approvals",
        dofi_officer: %w[list view approve request_amendment] },
      { key: "companies_documents", label: "Documents", fisherman: %w[list view create update] },
      { key: "companies_document_approvals", label: "Document Approvals",
        dofi_officer: %w[list view approve request_amendment] }
    ] }
  ].freeze

  SCOPE_KEYS = %i[shared dofi_officer fisherman].freeze
  ENTRIES = SECTIONS.each_with_index.flat_map do |section, section_index|
    section[:resources].each_with_index.flat_map do |resource, resource_index|
      scoped_actions = SCOPE_KEYS.flat_map do |scope|
        Array(resource[scope]).map { |action| [scope, action] }
      end
      scoped_actions.each_with_index.map do |(scope, action), action_index|
        {
          code: "#{resource[:key]}.#{action}", action: action, action_order: action_index + 1,
          name: action.humanize, platform_scope: scope.to_s,
          resource: resource[:key], resource_label: resource[:label], resource_order: resource_index + 1,
          section: section[:key], section_label: section[:label], section_order: section_index + 1
        }.freeze
      end
    end
  end.freeze
  BY_CODE = ENTRIES.index_by { |entry| entry[:code] }.freeze
  CODES = BY_CODE.keys.freeze
  RESOURCES = ENTRIES.group_by { |entry| entry[:resource] }.transform_values(&:freeze).freeze

  def self.fetch(code) = BY_CODE.fetch(code)
  def self.include?(code) = BY_CODE.key?(code)

  # The codes assignable to a role on the given platform — its own platform's codes, plus
  # anything shared. Computed straight from ENTRIES rather than the persisted `permissions`
  # table, so a stale platform_scope column on an existing row can never leak a code across
  # platforms — this module is the sole source of truth, per CLAUDE.md.
  def self.codes_for_platform(platform)
    allowed_scopes = [platform.to_s, "shared"]
    ENTRIES.select { |entry| allowed_scopes.include?(entry[:platform_scope]) }.pluck(:code)
  end
end
