class AddResourceNotNullToPermissions < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_column_null :permissions, :resource, false
    end
  end
end
