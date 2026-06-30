class AddFishermanRegistrationFieldsToUsers < ActiveRecord::Migration[8.1]
  # change_table bulk: true is rejected by strong_migrations (can't verify safety inside the block);
  # these are both simple nullable column additions, so separate statements are safe here.
  # rubocop:disable Rails/BulkChangeTable
  def change
    add_column :users, :designation, :string
    add_column :users, :rejection_reason, :text
  end
  # rubocop:enable Rails/BulkChangeTable
end
