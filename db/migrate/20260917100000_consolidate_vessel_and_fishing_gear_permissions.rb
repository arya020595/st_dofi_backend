class ConsolidateVesselAndFishingGearPermissions < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  class MigrationPermissionRole < ActiveRecord::Base
    self.table_name = "permission_roles"
  end

  PERMISSION_MAPPINGS = {
    "companies_fishing_gears.list" => "companies_vessels.list",
    "companies_fishing_gears.view" => "companies_vessels.view",
    "companies_fishing_gears.create" => "companies_vessels.create",
    "companies_fishing_gears.update" => "companies_vessels.update",
    "companies_fishing_gears.delete" => "companies_vessels.delete",
    "companies_fishing_gear_approvals.list" => "companies_vessel_approvals.list",
    "companies_fishing_gear_approvals.view" => "companies_vessel_approvals.view",
    "companies_fishing_gear_approvals.approve" => "companies_vessel_approvals.approve",
    "companies_fishing_gear_approvals.request_amendment" => "companies_vessel_approvals.request_amendment"
  }.freeze

  def up
    PERMISSION_MAPPINGS.each { |source_code, target_code| consolidate(source_code, target_code) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "fishing gear permissions are consolidated into vessel permissions"
  end

  private

  def consolidate(source_code, target_code)
    source = MigrationPermission.find_by(code: source_code)
    target = MigrationPermission.find_by(code: target_code)
    return unless source && target

    grant_target_to_source_roles(source, target)
    MigrationPermissionRole.where(permission_id: source.id).delete_all
    source.delete
  end

  def grant_target_to_source_roles(source, target)
    now = Time.current
    role_ids = MigrationPermissionRole.where(permission_id: source.id).pluck(:role_id)
    rows = role_ids.map { |role_id| { role_id: role_id, permission_id: target.id, created_at: now, updated_at: now } }
    MigrationPermissionRole.insert_all(rows, unique_by: %i[role_id permission_id]) if rows.any? # rubocop:disable Rails/SkipsModelValidations
  end
end
