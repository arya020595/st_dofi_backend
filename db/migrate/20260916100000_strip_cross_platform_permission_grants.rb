class StripCrossPlatformPermissionGrants < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  class MigrationPermissionRole < ActiveRecord::Base
    self.table_name = "permission_roles"
  end

  def up
    resync_permission_metadata
    strip_cross_platform_grants
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "cannot restore grants that violated the platform contract"
  end

  private

  # Belt-and-suspenders: Permission::CatalogRecord already forces platform_scope/section/etc. back
  # in sync with Permission::Catalog on every normal save, but a row can drift if something bypassed
  # that callback (e.g. a prior migration's bare ActiveRecord::Base class) and was never re-seeded.
  def resync_permission_metadata
    MigrationPermission.find_each do |permission|
      entry = Permission::Catalog::BY_CODE[permission.code]
      next unless entry

      permission.update_columns( # rubocop:disable Rails/SkipsModelValidations
        platform_scope: entry.fetch(:platform_scope),
        section: entry.fetch(:section),
        section_order: entry.fetch(:section_order),
        resource_order: entry.fetch(:resource_order)
      )
    end
  end

  # Roles::EnsureFishermanOwnerRole/EnsureFishermanAdminRole assign permissions via
  # Permission.assignable_to, which (before this contract fix) trusted the persisted
  # platform_scope column instead of Permission::Catalog. Any role provisioned while that column
  # was drifted may be holding a permission_roles grant outside its own platform's contract —
  # remove those now that the column has been resynced above.
  def strip_cross_platform_grants
    MigrationRole.find_each do |role|
      allowed_codes = Permission::Catalog.codes_for_platform(role.platform_scope)
      disallowed_permission_ids = MigrationPermission.where.not(code: allowed_codes).pluck(:id)
      next if disallowed_permission_ids.empty?

      MigrationPermissionRole.where(role_id: role.id, permission_id: disallowed_permission_ids).delete_all
    end
  end
end
