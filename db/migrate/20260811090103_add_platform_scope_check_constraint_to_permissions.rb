class AddPlatformScopeCheckConstraintToPermissions < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      add_check_constraint :permissions, "platform_scope IN ('fisherman', 'dofi_officer', 'shared')",
                           name: "check_permissions_platform_scope"
    end
  end
end
