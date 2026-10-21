class MakeUsersEmailUniqueIndexPartial < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :users, :email, algorithm: :concurrently
    add_index :users, :email, unique: true, where: "email <> ''", algorithm: :concurrently
  end
end
