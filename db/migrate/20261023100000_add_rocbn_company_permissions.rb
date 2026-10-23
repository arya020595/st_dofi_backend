# The ROCBN company lookup (Add Profiling > Select & Search Company) is gated by rocbn_companies.list/.view on the
# DoFi Officer platform. Deploys only run db:prepare (no re-seed), so this migration carries the change itself: it
# creates both permission rows and grants them to every officer-platform role that can create a company profile
# (the lookup is that form's first step), plus the seeded DoFi Officer role, which holds every catalog code
# (db/seeds/roles.rb). The metadata below is a frozen copy of what the catalog computes today, so a later catalog
# edit cannot change what this migration does on a fresh database.
class AddRocbnCompanyPermissions < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  class MigrationPermissionRole < ActiveRecord::Base
    self.table_name = "permission_roles"
  end

  METADATA = {
    resource: "rocbn_companies", platform_scope: "dofi_officer", section: "profiling", section_order: 3,
    resource_order: 5
  }.freeze
  ACTIONS = %w[list view].freeze

  def up
    ACTIONS.each { |action| grant(upsert_permission(action)) }
  end

  def down
    permission_ids = MigrationPermission.where(code: ACTIONS.map { |action| code_for(action) }).pluck(:id)
    MigrationPermissionRole.where(permission_id: permission_ids).delete_all
    MigrationPermission.where(id: permission_ids).delete_all
  end

  private

  def upsert_permission(action)
    permission = MigrationPermission.find_or_initialize_by(code: code_for(action))
    permission.update!(name: action.titleize, **METADATA)
    permission
  end

  def grant(permission)
    now = Time.current
    rows = recipient_role_ids.map do |role_id|
      { role_id: role_id, permission_id: permission.id, created_at: now, updated_at: now }
    end
    return if rows.empty?

    MigrationPermissionRole.insert_all(rows, unique_by: %i[role_id permission_id]) # rubocop:disable Rails/SkipsModelValidations
  end

  # Officer-platform roles only: the catalog keeps these codes away from fisherman roles.
  def recipient_role_ids
    officer_roles = MigrationRole.where(platform_scope: "dofi_officer")
    profile_creators = MigrationPermissionRole.where(
      permission_id: MigrationPermission.where(code: "company_profiles.create").select(:id)
    ).select(:role_id)

    officer_roles.where(id: profile_creators).or(officer_roles.where(kind: "DoFi Officer")).pluck(:id)
  end

  def code_for(action) = "#{METADATA.fetch(:resource)}.#{action}"
end
