# rubocop:disable Metrics/ClassLength
class EnforceSingleResourcePermissionContract < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  class MigrationPermissionRole < ActiveRecord::Base
    self.table_name = "permission_roles"
  end

  NEW_PERMISSIONS = [
    { code: "dashboard.list", platform_scope: "shared", section: "dashboard", section_order: 1,
      resource_order: 1 },
    { code: "manifest_approvals.list", platform_scope: "dofi_officer", section: "manifest", section_order: 2,
      resource_order: 2 },
    { code: "manifest_approvals.view", platform_scope: "dofi_officer", section: "manifest", section_order: 2,
      resource_order: 2 },
    { code: "manifest_approvals.approve_port_out", platform_scope: "dofi_officer", section: "manifest",
      section_order: 2, resource_order: 2 },
    { code: "manifest_approvals.request_amendment_port_out", platform_scope: "dofi_officer",
      section: "manifest", section_order: 2, resource_order: 2 },
    { code: "manifest_approvals.approve_port_in", platform_scope: "dofi_officer", section: "manifest",
      section_order: 2, resource_order: 2 },
    { code: "manifest_approvals.request_amendment_port_in", platform_scope: "dofi_officer",
      section: "manifest", section_order: 2, resource_order: 2 },
    { code: "permissions.list", platform_scope: "shared", section: "user_management", section_order: 6,
      resource_order: 3 },
    { code: "companies_vessel_approvals.request_amendment", platform_scope: "dofi_officer",
      section: "companies", section_order: 9, resource_order: 2 },
    { code: "companies_crew_approvals.request_amendment", platform_scope: "dofi_officer",
      section: "companies", section_order: 9, resource_order: 4 },
    { code: "companies_fishing_gear_approvals.request_amendment", platform_scope: "dofi_officer",
      section: "companies", section_order: 9, resource_order: 6 },
    { code: "companies_document_approvals.request_amendment", platform_scope: "dofi_officer",
      section: "companies", section_order: 9, resource_order: 8 },
    { code: "capture_report_verifications.list", platform_scope: "dofi_officer", section: "capture_reports",
      section_order: 10, resource_order: 2 },
    { code: "capture_report_verifications.view", platform_scope: "dofi_officer", section: "capture_reports",
      section_order: 10, resource_order: 2 },
    { code: "capture_report_verifications.request_amendment", platform_scope: "dofi_officer",
      section: "capture_reports", section_order: 10, resource_order: 2 }
  ].freeze

  def up
    create_permissions
    grant("dashboard.list", from: %w[dashboard.view])
    grant_to_all_roles("permissions.list")
    backfill_manifest_approvals
    backfill_capture_report_verifications
    backfill_request_amendments
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "canonical grants replace legacy permission semantics"
  end

  private

  def create_permissions
    NEW_PERMISSIONS.each do |definition|
      code = definition.fetch(:code)
      resource, action = code.split(".", 2)
      permission = MigrationPermission.find_or_initialize_by(code: code)
      permission.assign_attributes(
        definition.merge(resource: resource, name: action.humanize).except(:code)
      )
      permission.save!
    end
  end

  def backfill_manifest_approvals
    grant("manifest_approvals.list",
          from: %w[manifest_approvals.list manifest_approvals.view manifest_list.list manifest_list.view
                   manifests.list manifests.view], platform: "dofi_officer")
    grant("manifest_approvals.view",
          from: %w[manifest_approvals.view manifest_list.view manifests.view], platform: "dofi_officer")
    grant(
      "manifest_approvals.approve_port_out", from: %w[manifest_approvals.approve], platform: "dofi_officer"
    )
    grant(
      "manifest_approvals.approve_port_in", from: %w[manifest_approvals.approve], platform: "dofi_officer"
    )
    grant(
      "manifest_approvals.request_amendment_port_out",
      from: %w[manifest_approvals.amendment], platform: "dofi_officer"
    )
    grant(
      "manifest_approvals.request_amendment_port_in",
      from: %w[manifest_approvals.amendment], platform: "dofi_officer"
    )
  end

  def backfill_capture_report_verifications
    grant("capture_report_verifications.list",
          from: %w[capture_report_verifications.list capture_report_verifications.view capture_reports.list
                   capture_reports.view], platform: "dofi_officer")
    grant("capture_report_verifications.view",
          from: %w[capture_report_verifications.view capture_reports.view], platform: "dofi_officer")
    grant("capture_report_verifications.request_amendment",
          from: %w[capture_report_verifications.amendment], platform: "dofi_officer")
  end

  def backfill_request_amendments
    %w[vessel crew fishing_gear document].each do |resource|
      grant("companies_#{resource}_approvals.request_amendment",
            from: ["companies_#{resource}_approvals.amendment"], platform: "dofi_officer")
    end
  end

  def grant_to_all_roles(target_code)
    target = MigrationPermission.find_by!(code: target_code)
    now = Time.current
    rows = MigrationRole.pluck(:id).map do |role_id|
      { role_id: role_id, permission_id: target.id, created_at: now, updated_at: now }
    end
    insert_grants(rows)
  end

  def grant(target_code, from:, platform: nil)
    target = MigrationPermission.find_by!(code: target_code)
    roles = MigrationRole.joins("INNER JOIN permission_roles ON permission_roles.role_id = roles.id")
                         .joins("INNER JOIN permissions ON permissions.id = permission_roles.permission_id")
                         .where(permissions: { code: from })
    roles = roles.where(platform_scope: platform) if platform
    now = Time.current
    rows = roles.distinct.pluck(:id).map do |role_id|
      { role_id: role_id, permission_id: target.id, created_at: now, updated_at: now }
    end
    insert_grants(rows)
  end

  def insert_grants(rows)
    return if rows.empty?

    MigrationPermissionRole.insert_all(rows, unique_by: %i[role_id permission_id]) # rubocop:disable Rails/SkipsModelValidations
  end
end
# rubocop:enable Metrics/ClassLength
