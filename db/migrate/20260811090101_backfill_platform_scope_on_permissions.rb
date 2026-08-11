class BackfillPlatformScopeOnPermissions < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  # Snapshot of the resource-group classification at the time platform scoping was introduced.
  # db/seeds/permissions.rb is the living source of truth going forward (including for any new
  # groups/exceptions added after this migration runs) — this only needs to correctly classify what
  # exists in the table today. Keep in sync with db/seeds/permissions.rb's own comment explaining
  # each exception (profiling.delete, manifest_list.update) if this ever needs re-deriving.
  DOFI_OFFICER_ONLY_GROUPS = %w[
    dictionaries nationalities roles dofi_officer_users fisherman_approvals jetty_manager_approvals
    skip_reasons approval_remarks manifest_approvals companies_vessel_approvals companies_crew_approvals
    companies_fishing_gear_approvals companies_document_approvals capture_report_verifications
  ].freeze

  DOFI_OFFICER_ONLY_ACTIONS = {
    "ports" => %w[create update delete],
    "zones" => %w[create update delete],
    "fishing_gears" => %w[create update delete],
    "positions" => %w[create update delete],
    "profiling" => %w[delete],
    "manifest_list" => %w[update]
  }.freeze

  def up
    MigrationPermission.find_each do |permission|
      resource, action = permission.code.split(".", 2)
      scope = platform_scope_for(resource, action)
      permission.update_column(:platform_scope, scope) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    # no-op: platform_scope column removal is handled by the migration that added it
  end

  private

  def platform_scope_for(resource, action)
    return "dofi_officer" if DOFI_OFFICER_ONLY_GROUPS.include?(resource)
    return "dofi_officer" if DOFI_OFFICER_ONLY_ACTIONS[resource]&.include?(action)

    "shared"
  end
end
