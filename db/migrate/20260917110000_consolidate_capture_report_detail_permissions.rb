class ConsolidateCaptureReportDetailPermissions < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  class MigrationPermissionRole < ActiveRecord::Base
    self.table_name = "permission_roles"
  end

  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  DETAIL_PERMISSION_CODES = %w[
    fish_capture_details.list fish_capture_details.view fish_capture_details.create fish_capture_details.update
    fish_capture_details.delete fish_capture_details.bulk_sync fishing_gear_details.list fishing_gear_details.view
    fishing_gear_details.create fishing_gear_details.update fishing_gear_details.delete
  ].freeze

  def up
    remove_admin_capture_report_access
    consolidate_detail_permissions
    sync_target_metadata
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "capture report detail permissions are consolidated"
  end

  private

  def remove_admin_capture_report_access
    capture_report_permissions = MigrationPermission.where("code LIKE ?", "capture_reports.%")
    admin_role_ids = MigrationRole.where.not(platform_scope: "fisherman").select(:id)
    MigrationPermissionRole.where(permission_id: capture_report_permissions, role_id: admin_role_ids).delete_all
  end

  def consolidate_detail_permissions
    target = MigrationPermission.find_by(code: "capture_reports.update")
    sources = MigrationPermission.where(code: DETAIL_PERMISSION_CODES)
    grant_update_to_fisherman_roles(sources, target) if target && sources.exists?
    MigrationPermissionRole.where(permission_id: sources).delete_all
    sources.delete_all
  end

  def grant_update_to_fisherman_roles(sources, target)
    fisherman_role_ids = MigrationPermissionRole.where(permission_id: sources)
                                                .joins("INNER JOIN roles ON roles.id = permission_roles.role_id")
                                                .where(roles: { platform_scope: "fisherman" })
                                                .distinct
                                                .pluck(:role_id)
    now = Time.current
    rows = fisherman_role_ids.map do |role_id|
      { role_id: role_id, permission_id: target.id, created_at: now, updated_at: now }
    end
    MigrationPermissionRole.insert_all(rows, unique_by: %i[role_id permission_id]) if rows.any? # rubocop:disable Rails/SkipsModelValidations
  end

  def sync_target_metadata
    update_metadata("capture_reports", platform_scope: "fisherman", resource_order: 3)
    update_metadata("capture_report_verifications", platform_scope: "dofi_officer", resource_order: 4)
  end

  def update_metadata(resource, platform_scope:, resource_order:)
    MigrationPermission.where(resource: resource).update_all( # rubocop:disable Rails/SkipsModelValidations
      platform_scope: platform_scope,
      section: "manifest",
      section_order: 2,
      resource_order: resource_order,
      updated_at: Time.current
    )
  end
end
