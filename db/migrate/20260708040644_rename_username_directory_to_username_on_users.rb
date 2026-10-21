class RenameUsernameDirectoryToUsernameOnUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    safety_assured do
      rename_column :users, :username_directory, :username
    end

    add_index :users, :username, unique: true, algorithm: :concurrently
  end
end
