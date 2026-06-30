class AddContactNoToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :contact_no, :string
  end
end
