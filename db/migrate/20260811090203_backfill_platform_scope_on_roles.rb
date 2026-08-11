class BackfillPlatformScopeOnRoles < ActiveRecord::Migration[8.1]
  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  DOFI_OFFICER_KINDS = ["DoFi Officer", "Jetty Manager"].freeze

  # Every role except the legacy singleton "Fisherman" kind row is admin-platform today — there is
  # no fisherman-custom-role capability before this migration, so every kind:nil custom role was
  # necessarily created via the admin-only Roles API. The legacy Fisherman row itself is handled
  # (migrated to per-company Owner roles, then deleted) by MigrateFishermenToCompanyScopedOwnerRoles
  # immediately after this migration, so it's deliberately left alone here (still kind: "Fisherman",
  # not matched by either of the two conditions below). Two explicit update_all calls, not
  # `where.not(kind: "Fisherman")` — NULL != 'Fisherman' is UNKNOWN under SQL three-valued logic, so
  # a single negated WHERE would silently skip every kind:nil custom role.
  def up
    # rubocop:disable Rails/SkipsModelValidations
    MigrationRole.where(kind: DOFI_OFFICER_KINDS).update_all(platform_scope: "dofi_officer")
    MigrationRole.where(kind: nil).update_all(platform_scope: "dofi_officer")
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    # no-op: platform_scope column removal is handled by the migration that added it
  end
end
