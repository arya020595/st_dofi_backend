class AddPlatformScopeToPermissions < ActiveRecord::Migration[8.1]
  def change
    # Defaults to "shared" (the least-restrictive value — visible/assignable on both platforms), not
    # left nullable-with-no-default: the only real path that creates Permission rows is
    # db/seeds/permissions.rb, which always classifies every code explicitly regardless of this
    # default — this exists purely so ad-hoc `Permission.find_or_create_by!(code: ...)` calls
    # scattered across tests (which don't care about platform isolation) don't all need touching.
    add_column :permissions, :platform_scope, :string, default: "shared"
  end
end
