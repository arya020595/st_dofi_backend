# "Admin Accounts" became "External Users" (User Management) and gained create/update/
# delete for the Jetty Manager tab. Deploys only run db:prepare (no re-seed), so this migration carries
# the change itself: existing admin_accounts.* rows are renamed in place — permission_roles point at the
# permission id, so every role's existing grant survives untouched — then all seven external_users.*
# codes are ensured and granted to the DoFi Officer role, matching db/seeds/roles.rb's
# `permission_codes: :all`. Ensuring all seven (not only the new three) covers an environment that
# never had admin_accounts.* rows to rename.
class RenameAdminAccountsToExternalUsers < ActiveRecord::Migration[8.1]
  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  class MigrationPermissionRole < ActiveRecord::Base
    self.table_name = "permission_roles"
  end

  RENAMED_ACTIONS = %w[list view deactivate reactivate].freeze
  NEW_ACTIONS = %w[create update delete].freeze
  EXTERNAL_USERS_METADATA = {
    resource: "external_users", platform_scope: "dofi_officer", section: "user_management", section_order: 6,
    resource_order: 5
  }.freeze
  ADMIN_ACCOUNTS_METADATA = {
    resource: "admin_accounts", platform_scope: "dofi_officer", section: "user_management", section_order: 6,
    resource_order: 4
  }.freeze

  def up
    RENAMED_ACTIONS.each { |action| rename(action, from: ADMIN_ACCOUNTS_METADATA, to: EXTERNAL_USERS_METADATA) }
    (RENAMED_ACTIONS + NEW_ACTIONS).each do |action|
      grant_to_dofi_officer(upsert_permission(action, EXTERNAL_USERS_METADATA))
    end
  end

  def down
    MigrationPermission.where(code: NEW_ACTIONS.map { |action| code_for(EXTERNAL_USERS_METADATA, action) })
                       .find_each do |permission|
      MigrationPermissionRole.where(permission_id: permission.id).delete_all
      permission.delete
    end
    RENAMED_ACTIONS.each { |action| rename(action, from: EXTERNAL_USERS_METADATA, to: ADMIN_ACCOUNTS_METADATA) }
  end

  private

  def rename(action, from:, to:)
    source = MigrationPermission.find_by(code: code_for(from, action))
    return unless source

    target = MigrationPermission.find_by(code: code_for(to, action))
    if target
      # The target already exists (e.g. seeds ran before this migration): fold the source's grants
      # into it rather than colliding on the unique code index.
      move_grants(from: source, to: target)
      source.delete
    else
      source.update!(code: code_for(to, action), name: action.titleize, **to)
    end
  end

  def upsert_permission(action, metadata)
    permission = MigrationPermission.find_or_initialize_by(code: code_for(metadata, action))
    permission.update!(name: action.titleize, **metadata)
    permission
  end

  def grant_to_dofi_officer(permission)
    now = Time.current
    rows = MigrationRole.where(kind: "DoFi Officer").pluck(:id).map do |role_id|
      { role_id: role_id, permission_id: permission.id, created_at: now, updated_at: now }
    end
    insert_grants(rows)
  end

  def move_grants(from:, to:)
    now = Time.current
    rows = MigrationPermissionRole.where(permission_id: from.id).pluck(:role_id).map do |role_id|
      { role_id: role_id, permission_id: to.id, created_at: now, updated_at: now }
    end
    insert_grants(rows)
    MigrationPermissionRole.where(permission_id: from.id).delete_all
  end

  def insert_grants(rows)
    return if rows.empty?

    MigrationPermissionRole.insert_all(rows, unique_by: %i[role_id permission_id]) # rubocop:disable Rails/SkipsModelValidations
  end

  def code_for(metadata, action) = "#{metadata.fetch(:resource)}.#{action}"
end
