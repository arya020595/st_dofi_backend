# The size is dominated by the immutable permission snapshot required for deterministic installs.
# rubocop:disable Metrics/ClassLength
class ExpandCanonicalPermissions < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"

    has_many :permission_roles, class_name: "ExpandCanonicalPermissions::MigrationPermissionRole",
                                foreign_key: :permission_id, inverse_of: :permission
  end

  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"

    has_many :permission_roles, class_name: "ExpandCanonicalPermissions::MigrationPermissionRole",
                                foreign_key: :role_id, inverse_of: :role
    has_many :permissions, through: :permission_roles, source: :permission
  end

  class MigrationPermissionRole < ActiveRecord::Base
    self.table_name = "permission_roles"

    belongs_to :role, class_name: "ExpandCanonicalPermissions::MigrationRole", inverse_of: :permission_roles
    belongs_to :permission, class_name: "ExpandCanonicalPermissions::MigrationPermission",
                            inverse_of: :permission_roles
  end

  # Immutable snapshot of the canonical catalog at cutover time. Migrations deliberately do not
  # depend on the live Permission model/catalog, so a future catalog edit cannot change this
  # migration when it is run on a newly provisioned database.
  CANONICAL_SECTIONS = [
    { section: "dashboard", resources: [
      { resource: "dashboard", shared: %w[view] }
    ] },
    { section: "manifest", resources: [
      { resource: "manifests",
        shared: %w[list view create update delete offline_bundle submit_port_out resubmit_port_out submit_port_in
                   resubmit_port_in skip_capture_report] },
      { resource: "manifest_approvals", dofi_officer: %w[approve amendment] },
      { resource: "manifest_minor_fishermen", shared: %w[list view create delete] },
      { resource: "manifest_expenses", shared: %w[view create update] }
    ] },
    { section: "profiling", resources: [
      { resource: "company_profiles", shared: %w[list view create update], dofi_officer: %w[delete] },
      { resource: "company_profile_contacts", shared: %w[create update], dofi_officer: %w[delete] }
    ] },
    { section: "dictionary", resources: [
      { resource: "dictionaries", shared: %w[list], dofi_officer: %w[view create update delete] },
      { resource: "dictionary_groups", shared: %w[list], dofi_officer: %w[view create update delete] },
      { resource: "dictionary_families", shared: %w[list], dofi_officer: %w[view create update delete] }
    ] },
    { section: "master_data", resources: [
      { resource: "ports", shared: %w[list view], dofi_officer: %w[create update delete] },
      { resource: "zones", shared: %w[list view], dofi_officer: %w[create update delete] },
      { resource: "fishing_gears", shared: %w[list view], dofi_officer: %w[create update delete] },
      { resource: "nationalities", shared: %w[list view], dofi_officer: %w[create update delete] },
      { resource: "positions", shared: %w[list view], dofi_officer: %w[create update delete] },
      { resource: "skip_reasons", shared: %w[list view], dofi_officer: %w[create update delete] }
    ] },
    { section: "user_management", resources: [
      { resource: "roles", dofi_officer: %w[list view create update delete] },
      { resource: "dofi_officer_users", dofi_officer: %w[list view create update delete] }
    ] },
    { section: "account_management", resources: [
      { resource: "fisherman_users", fisherman: %w[list view create update delete] },
      { resource: "fisherman_roles", fisherman: %w[list view create update delete] }
    ] },
    { section: "fins_approval", resources: [
      { resource: "fisherman_approvals",
        dofi_officer: %w[list view approve reject deactivate reactivate revoke] },
      { resource: "jetty_manager_approvals",
        dofi_officer: %w[list view approve reject deactivate reactivate revoke] },
      { resource: "approval_remarks", dofi_officer: %w[list view create update delete] }
    ] },
    { section: "companies", resources: [
      { resource: "companies_vessels", shared: %w[list view create update delete images] },
      { resource: "companies_vessel_approvals", dofi_officer: %w[list view approve amendment] },
      { resource: "companies_crews", shared: %w[list view create update delete] },
      { resource: "companies_crew_approvals", dofi_officer: %w[list view approve amendment] },
      { resource: "companies_fishing_gears", shared: %w[list view create update delete] },
      { resource: "companies_fishing_gear_approvals", dofi_officer: %w[list view approve amendment] },
      { resource: "companies_documents", shared: %w[list view create update] },
      { resource: "companies_document_approvals", dofi_officer: %w[list view approve amendment] }
    ] },
    { section: "capture_reports", resources: [
      { resource: "capture_reports", shared: %w[list view create update resubmit] },
      { resource: "capture_report_verifications", dofi_officer: %w[verify amendment] },
      { resource: "fish_capture_details", shared: %w[list view create update delete bulk_sync] },
      { resource: "fishing_gear_details", shared: %w[list view create update delete] }
    ] }
  ].freeze

  VIEW_IMPLIES_LIST = %w[
    approval_remarks companies_vessels companies_vessel_approvals companies_crews
    companies_crew_approvals companies_fishing_gears companies_fishing_gear_approvals
    companies_documents companies_document_approvals dictionaries ports zones fishing_gears
    nationalities positions skip_reasons roles dofi_officer_users fisherman_users fisherman_roles
    fisherman_approvals jetty_manager_approvals capture_reports manifest_minor_fishermen
  ].freeze

  MANIFEST_READ_SOURCES = %w[
    manifest.view manifest.create manifest_list.view manifest_form.view manifest_form.create
  ].freeze
  MANIFEST_WRITE_SOURCES = %w[manifest.create manifest_form.create].freeze

  def up
    create_canonical_permissions
    backfill_same_resource_list_access
    backfill_same_resource_action_access
    backfill_manifest_access
    backfill_profile_access
    backfill_dictionary_access
    backfill_capture_verification_access
    backfill_capture_detail_access
    backfill_company_fishing_gear_access
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "canonical grants merge several legacy permission semantics"
  end

  private

  def create_canonical_permissions
    CANONICAL_SECTIONS.each_with_index do |section, section_index|
      section.fetch(:resources).each_with_index do |definition, resource_index|
        %i[shared dofi_officer fisherman].each do |platform_scope|
          Array(definition[platform_scope]).each do |action|
            resource = definition.fetch(:resource)
            permission = MigrationPermission.find_or_initialize_by(code: "#{resource}.#{action}")
            permission.assign_attributes(
              name: action.humanize,
              platform_scope: platform_scope.to_s,
              resource: resource,
              resource_order: resource_index + 1,
              section: section.fetch(:section),
              section_order: section_index + 1
            )
            permission.save!
          end
        end
      end
    end
  end

  def backfill_same_resource_list_access
    VIEW_IMPLIES_LIST.each { |resource| grant("#{resource}.list", from: ["#{resource}.view"]) }
  end

  def backfill_same_resource_action_access
    grant("companies_vessels.images", from: %w[companies_vessels.view])

    %w[create delete].each do |action|
      grant("manifest_minor_fishermen.#{action}",
            from: %w[manifest_minor_fishermen.create manifest_minor_fishermen.delete])
    end
    %w[create update].each do |action|
      grant("manifest_expenses.#{action}", from: %w[manifest_expenses.create manifest_expenses.update])
      grant("capture_reports.#{action}", from: %w[capture_reports.create capture_reports.update])
    end
    grant("capture_reports.resubmit", from: %w[capture_reports.create capture_reports.update])
  end

  def backfill_manifest_access
    read_targets = %w[
      manifests.list manifests.view manifests.offline_bundle dashboard.view
      ports.list ports.view zones.list zones.view fishing_gears.list fishing_gears.view
      nationalities.list nationalities.view positions.list positions.view skip_reasons.list skip_reasons.view
      capture_reports.list capture_reports.view manifest_minor_fishermen.list manifest_minor_fishermen.view
      manifest_expenses.view fish_capture_details.list fish_capture_details.view
      fishing_gear_details.list fishing_gear_details.view
    ]
    write_targets = %w[
      manifests.create manifests.update manifests.submit_port_out manifests.resubmit_port_out
      manifests.submit_port_in manifests.resubmit_port_in manifests.skip_capture_report
      capture_reports.create capture_reports.update capture_reports.resubmit
      manifest_minor_fishermen.create manifest_minor_fishermen.delete
      manifest_expenses.create manifest_expenses.update
      fish_capture_details.create fish_capture_details.update fish_capture_details.delete
      fish_capture_details.bulk_sync fishing_gear_details.create fishing_gear_details.update
      fishing_gear_details.delete companies_vessels.list companies_crews.list dictionaries.list
      dictionary_groups.list dictionary_families.list
    ]

    read_targets.each { |target| grant(target, from: MANIFEST_READ_SOURCES, platform: "fisherman") }
    write_targets.each { |target| grant(target, from: MANIFEST_WRITE_SOURCES, platform: "fisherman") }
    grant("manifests.delete", from: %w[manifest.delete manifest_list.delete], platform: "fisherman")

    grant("manifests.list", from: %w[manifest_list.list manifest_approvals.list], platform: "dofi_officer")
    grant("manifests.view", from: %w[manifest_list.view manifest_form.view manifest_approvals.view],
                            platform: "dofi_officer")
    transition_actions = %w[
      create update submit_port_out resubmit_port_out submit_port_in resubmit_port_in skip_capture_report
    ]
    transition_actions.each do |action|
      grant("manifests.#{action}", from: %w[manifest_form.create], platform: "dofi_officer")
    end
    grant("manifests.update", from: %w[manifest_list.update], platform: "dofi_officer")
    grant("manifests.delete", from: %w[manifest_list.delete], platform: "dofi_officer")
    grant("manifests.offline_bundle",
          from: %w[manifest_list.view manifest_form.view manifest_approvals.view], platform: "dofi_officer")
  end

  def backfill_profile_access
    grant("company_profiles.list", from: %w[profiling.list profiling.view])
    grant("company_profiles.view", from: %w[profiling.view])
    grant("company_profiles.create", from: %w[profiling.create])
    grant("company_profiles.update", from: %w[profiling.update], platform: "dofi_officer")
    grant("company_profiles.update", from: %w[profiling.view], platform: "fisherman")
    grant("company_profiles.delete", from: %w[profiling.delete], platform: "dofi_officer")

    grant("company_profile_contacts.create", from: %w[profiling.create])
    grant("company_profile_contacts.update", from: %w[profiling.update], platform: "dofi_officer")
    grant("company_profile_contacts.update", from: %w[profiling.view], platform: "fisherman")
    grant("company_profile_contacts.delete", from: %w[profiling.delete], platform: "dofi_officer")
  end

  def backfill_dictionary_access
    %w[dictionary_groups dictionary_families].each do |resource|
      %w[list view create update delete].each do |action|
        sources = action == "list" ? %w[dictionaries.list dictionaries.view] : ["dictionaries.#{action}"]
        grant("#{resource}.#{action}", from: sources)
      end
    end
  end

  def backfill_capture_verification_access
    grant("capture_reports.list", from: %w[capture_report_verifications.list capture_report_verifications.view])
    grant("capture_reports.view", from: %w[capture_report_verifications.view])
  end

  def backfill_capture_detail_access
    %w[fish_capture_details fishing_gear_details].each do |resource|
      grant("#{resource}.list", from: %w[capture_reports.list capture_reports.view])
      grant("#{resource}.view", from: %w[capture_reports.view])
      grant("#{resource}.create", from: %w[capture_reports.create capture_reports.update])
      grant("#{resource}.update", from: %w[capture_reports.create capture_reports.update])
      grant("#{resource}.delete", from: %w[capture_reports.create capture_reports.update])
    end
    grant("fish_capture_details.bulk_sync", from: %w[capture_reports.create capture_reports.update])
  end

  def backfill_company_fishing_gear_access
    %w[view create update delete].each do |action|
      grant("companies_fishing_gears.#{action}", from: ["companies_vessels.#{action}"], platform: "fisherman")
    end
    grant("companies_fishing_gears.list",
          from: %w[companies_vessels.list companies_vessels.view], platform: "fisherman")
  end

  def grant(target_code, from:, platform: nil)
    target = MigrationPermission.find_by!(code: target_code)
    roles = MigrationRole.joins(permission_roles: :permission).where(permissions: { code: from })
    roles = roles.where(platform_scope: platform) if platform
    now = Time.current
    rows = roles.distinct.pluck(:id).map do |role_id|
      { role_id: role_id, permission_id: target.id, created_at: now, updated_at: now }
    end
    # The join has a unique DB index; insert_all gives atomic, idempotent duplicate prevention.
    MigrationPermissionRole.insert_all(rows, unique_by: %i[role_id permission_id]) if rows.any? # rubocop:disable Rails/SkipsModelValidations
  end
end
# rubocop:enable Metrics/ClassLength
