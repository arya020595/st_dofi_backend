module Permission::Taxonomy
  extend ActiveSupport::Concern

  # Grouping/display metadata for the "Add User Role" UI only (Section -> Resource -> Actions), so
  # the frontend can render checkboxes grouped/labeled/ordered without hardcoding a copy of this
  # taxonomy. resource/section/section_order/resource_order/resource_label/section_label are
  # PRESENTATION ONLY — authorization must always go through Permission#code (see
  # Permission::PlatformScoping, PermissionPlatformValidation, Pundit policies). Never branch
  # authorization logic on these fields. db/seeds/permissions.rb is the only writer of
  # PERMISSION_GROUPS (which resource/action pairs exist); this taxonomy only says how to
  # display/group them, and is the single source of truth for that — db/seeds/permissions.rb does
  # not keep its own copy.
  #
  # Labels are plain English strings (no Mobility/bilingual support yet), matching the existing
  # User::APPROVAL_STATUS_LABELS precedent for "small set of machine keys -> human label" — Mobility
  # is configured in this repo but not adopted by any model yet, so introducing it here would be a
  # bigger, novel lift for a presentation-only concern that this lighter pattern already covers.
  #
  # Section order/membership mirrors the "Add New User Role" (DoFi Officer) and "Add Role" (Fisherman
  # company) mockups. user_management (DoFi Officer: roles, dofi_officer_users) and account_management
  # (Fisherman: fisherman_users, fisherman_roles) are deliberately separate sections, even though they
  # cover the same underlying concept — they never render together (platform-filtered before grouping),
  # so each gets one authoritative static label instead of sharing one key with two possible labels.
  # Resources not shown in either mockup (manifest, manifest_minor_fishermen, manifest_expenses,
  # companies_*, capture_reports*) are kept in their existing section, appended after the ones the
  # mockups do show, with best-guess labels flagged for product review.
  PERMISSION_TAXONOMY = [
    { section: "dashboard", section_label: "Dashboard",
      resources: [{ key: "dashboard", label: "Dashboard" }] },
    { section: "manifest", section_label: "Manifest",
      resources: [
        { key: "manifest_list", label: "Manifest List" },
        { key: "manifest_form", label: "Request for Port-Out" },
        { key: "manifest_approvals", label: "Approval List" },
        { key: "manifest", label: "Manifest (Full Access)" },
        { key: "manifest_minor_fishermen", label: "Minor Fishermen" },
        { key: "manifest_expenses", label: "Manifest Expenses" }
      ] },
    { section: "profiling", section_label: "Profiling",
      resources: [{ key: "profiling", label: "Profiling" }] },
    { section: "dictionary", section_label: "Dictionary",
      resources: [{ key: "dictionaries", label: "Dictionary" }] },
    { section: "master_data", section_label: "Master Data",
      resources: [
        { key: "ports", label: "Port" },
        { key: "zones", label: "Zone" },
        { key: "fishing_gears", label: "Fishing Gear" },
        { key: "nationalities", label: "Nationality" },
        { key: "positions", label: "Position" },
        { key: "skip_reasons", label: "Reason" }
      ] },
    { section: "user_management", section_label: "User Management",
      resources: [
        { key: "roles", label: "Roles" },
        { key: "dofi_officer_users", label: "DoFi Officer Users" }
      ] },
    { section: "account_management", section_label: "Account Management",
      resources: [
        { key: "fisherman_users", label: "Users" },
        { key: "fisherman_roles", label: "Roles" }
      ] },
    { section: "fins_approval", section_label: "FINS Approval",
      resources: [
        { key: "fisherman_approvals", label: "Fisherman Approval" },
        { key: "jetty_manager_approvals", label: "Jetty Manager Approval" },
        { key: "approval_remarks", label: "Approval Request" }
      ] },
    { section: "companies", section_label: "Companies",
      resources: [
        { key: "companies_vessels", label: "Vessels" },
        { key: "companies_vessel_approvals", label: "Vessel Approvals" },
        { key: "companies_crews", label: "Crews" },
        { key: "companies_crew_approvals", label: "Crew Approvals" },
        { key: "companies_fishing_gears", label: "Fishing Gears" },
        { key: "companies_fishing_gear_approvals", label: "Fishing Gear Approvals" },
        { key: "companies_documents", label: "Documents" },
        { key: "companies_document_approvals", label: "Document Approvals" }
      ] },
    { section: "capture_reports", section_label: "Capture Reports",
      resources: [
        { key: "capture_reports", label: "Capture Reports" },
        { key: "capture_report_verifications", label: "Capture Report Verifications" }
      ] }
  ].freeze
  SECTIONS = PERMISSION_TAXONOMY.pluck(:section).freeze
  RESOURCE_TAXONOMY = PERMISSION_TAXONOMY.each_with_index.with_object({}) do |(entry, section_index), memo|
    entry[:resources].each_with_index do |resource, resource_index|
      memo[resource[:key]] = {
        section: entry[:section],
        section_label: entry[:section_label],
        section_order: section_index + 1,
        resource_label: resource[:label],
        resource_order: resource_index + 1
      }
    end
  end.freeze

  included do
    before_validation :sync_resource_and_grouping

    # section/section_order/resource_order are intentionally NOT validated for inclusion/numericality:
    # sync_resource_and_grouping is their only writer and derives them purely from PERMISSION_TAXONOMY,
    # which makes SECTIONS by construction — there's no reachable path where they'd disagree.
    validates :resource, presence: true
  end

  def resource_label
    RESOURCE_TAXONOMY.dig(resource, :resource_label) || resource&.humanize
  end

  def section_label
    RESOURCE_TAXONOMY.dig(resource, :section_label) || section&.humanize
  end

  private

  # Keeps resource/section/section_order/resource_order permanently derived from code — never
  # independently settable, so code = "ports.view" can never end up with a mismatched resource.
  # Unrecognized resources (e.g. ad-hoc test permissions) simply get nil grouping fields.
  def sync_resource_and_grouping
    self.resource = code.to_s.split(".", 2).first
    info = RESOURCE_TAXONOMY[resource]
    self.section = info && info[:section]
    self.section_order = info && info[:section_order]
    self.resource_order = info && info[:resource_order]
  end
end
