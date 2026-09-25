class AddFishermanRegistrationFieldsToUsers < ActiveRecord::Migration[8.1]
  # change_table bulk: true is rejected by strong_migrations (can't verify safety inside the block);
  # these are both simple nullable column additions, so separate statements are safe here.
  def change
    add_column :users, :designation, :string
  end
end
