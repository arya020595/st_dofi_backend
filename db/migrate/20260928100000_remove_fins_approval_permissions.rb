# The FINS Approval module (Fisherman Approval, Jetty Manager Approval, Approval Remarks) was removed:
# officer-created Jetty Managers start active and Company Profiling-provisioned Fishermen start
# claimable, so nothing is left to approve. Deploys only run db:prepare (no re-seed), and
# 20260910110000_expand_canonical_permissions recreates these rows on every fresh migrate, so this
# migration deletes them — grants first, since permission_roles points at the permission id.
class RemoveFinsApprovalPermissions < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  class MigrationPermissionRole < ActiveRecord::Base
    self.table_name = "permission_roles"
  end

  REMOVED_RESOURCES = {
    "fisherman_approvals" => { resource_order: 1, actions: %w[list view approve reject deactivate reactivate revoke] },
    "jetty_manager_approvals" => {
      resource_order: 2, actions: %w[list view approve reject deactivate reactivate revoke]
    },
    "approval_remarks" => { resource_order: 3, actions: %w[list view create update delete] }
  }.freeze

  def up
    permission_ids = removed_permissions.pluck(:id)
    MigrationPermissionRole.where(permission_id: permission_ids).delete_all
    MigrationPermission.where(id: permission_ids).delete_all
  end

  def down
    now = Time.current
    officer_role_ids = MigrationRole.where(kind: "DoFi Officer").pluck(:id)

    REMOVED_RESOURCES.each do |resource, definition|
      definition.fetch(:actions).each do |action|
        permission = MigrationPermission.find_or_initialize_by(code: "#{resource}.#{action}")
        permission.update!(name: action.titleize, resource: resource, platform_scope: "dofi_officer",
                           section: "fins_approval", section_order: 8,
                           resource_order: definition.fetch(:resource_order))
        insert_grants(officer_role_ids.map do |role_id|
          { role_id: role_id, permission_id: permission.id, created_at: now, updated_at: now }
        end)
      end
    end
  end

  private

  def removed_permissions
    MigrationPermission.where(
      REMOVED_RESOURCES.keys.map { "code LIKE ?" }.join(" OR "),
      *REMOVED_RESOURCES.keys.map { |resource| "#{resource}.%" }
    )
  end

  def insert_grants(rows)
    return if rows.empty?

    MigrationPermissionRole.insert_all(rows, unique_by: %i[role_id permission_id]) # rubocop:disable Rails/SkipsModelValidations
  end
end
