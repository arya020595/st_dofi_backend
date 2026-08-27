class AddFishermanFlowBFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    # rubocop:disable Rails/BulkChangeTable
    add_column :users, :fisherman_status, :string
    add_column :users, :normalized_ic_number, :string
    add_column :users, :provisioning_source, :string
    add_column :users, :claimed_at, :datetime
    add_column :users, :approved_at, :datetime
    add_column :users, :approved_by_id, :uuid
    add_column :users, :created_by_id, :uuid
    # rubocop:enable Rails/BulkChangeTable

    add_foreign_key :users, :users, column: :approved_by_id, validate: false
    add_foreign_key :users, :users, column: :created_by_id, validate: false
  end
end
