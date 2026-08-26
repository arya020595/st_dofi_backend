class AddIsLocalCitizenshipToNationalities < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:nationalities, :is_local_citizenship)

    add_column :nationalities, :is_local_citizenship, :boolean, null: false, default: false
  end
end
