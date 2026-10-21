class AddPlatformScopeNotNullToPermissions < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_column_null :permissions, :platform_scope, false
    end
  end
end
