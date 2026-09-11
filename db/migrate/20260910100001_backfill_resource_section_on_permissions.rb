class BackfillResourceSectionOnPermissions < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  # Snapshot of the section taxonomy at the time grouping metadata was introduced.
  # Permission::PERMISSION_TAXONOMY is the living source of truth going forward (including for any new
  # resources/sections added after this migration runs) — this only needs to correctly classify what
  # exists in the table today.
  TAXONOMY = [
    { section: "dashboard", resources: %w[dashboard] },
    { section: "manifest",
      resources: %w[manifest_list manifest_form manifest_approvals manifest manifest_minor_fishermen
                    manifest_expenses] },
    { section: "profiling", resources: %w[profiling] },
    { section: "dictionary", resources: %w[dictionaries] },
    { section: "master_data",
      resources: %w[ports zones fishing_gears nationalities positions skip_reasons] },
    { section: "user_management", resources: %w[roles dofi_officer_users] },
    { section: "account_management", resources: %w[fisherman_users fisherman_roles] },
    { section: "fins_approval", resources: %w[fisherman_approvals jetty_manager_approvals approval_remarks] },
    { section: "companies",
      resources: %w[companies_vessels companies_vessel_approvals companies_crews companies_crew_approvals
                    companies_fishing_gears companies_fishing_gear_approvals companies_documents
                    companies_document_approvals] },
    { section: "capture_reports", resources: %w[capture_reports capture_report_verifications] }
  ].freeze

  RESOURCE_TAXONOMY = TAXONOMY.each_with_index.with_object({}) do |(entry, section_index), memo|
    entry[:resources].each_with_index do |resource, resource_index|
      memo[resource] = {
        section: entry[:section],
        section_order: section_index + 1,
        resource_order: resource_index + 1
      }
    end
  end.freeze

  def up
    MigrationPermission.find_each do |permission|
      resource = permission.code.split(".", 2).first
      info = RESOURCE_TAXONOMY[resource]

      permission.update_columns( # rubocop:disable Rails/SkipsModelValidations
        resource: resource,
        section: info && info[:section],
        section_order: info && info[:section_order],
        resource_order: info && info[:resource_order]
      )
    end
  end

  def down
    # no-op: column removal is handled by the migration that added these columns
  end
end
