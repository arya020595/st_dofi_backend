class MigrateFishermenToCompanyScopedOwnerRoles < ActiveRecord::Migration[8.1]
  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
    has_many :permission_roles, class_name: "MigrationPermissionRole", foreign_key: :role_id, inverse_of: :role,
                                dependent: :destroy
  end

  class MigrationPermissionRole < ActiveRecord::Base
    self.table_name = "permission_roles"
    belongs_to :role, class_name: "MigrationRole"
  end

  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  # This is the last migration that can still address the legacy role by kind — the very next
  # migration (AddPlatformScopeNotNullToRoles) makes platform_scope mandatory, and the legacy row
  # would otherwise be left with platform_scope: nil since BackfillPlatformScopeOnRoles deliberately
  # skips it (see that migration's comment).
  def up
    legacy_role = MigrationRole.find_by(kind: "Fisherman")
    return unless legacy_role

    legacy_permission_ids = legacy_role.permission_roles.pluck(:permission_id)

    company_ids = MigrationUser.where(role_id: legacy_role.id).where.not(company_profile_id: nil)
                               .distinct.pluck(:company_profile_id)
    company_ids.each do |company_profile_id|
      owner_role = MigrationRole.create!(
        name: "Owner", description: "Full access to this company's fisherman-platform data.",
        platform_scope: "fisherman", company_profile_id: company_profile_id, is_default: true
      )
      legacy_permission_ids.each do |permission_id|
        MigrationPermissionRole.create!(role: owner_role, permission_id: permission_id)
      end

      # rubocop:disable Rails/SkipsModelValidations
      MigrationUser.where(role_id: legacy_role.id,
                          company_profile_id: company_profile_id).update_all(role_id: owner_role.id)
      # rubocop:enable Rails/SkipsModelValidations
    end

    legacy_role.destroy!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
