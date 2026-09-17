class AddDiscardedAtToPortsAndZones < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :ports, :discarded_at, :datetime
    add_index :ports, :discarded_at, algorithm: :concurrently

    add_column :zones, :discarded_at, :datetime
    add_index :zones, :discarded_at, algorithm: :concurrently
  end
end
