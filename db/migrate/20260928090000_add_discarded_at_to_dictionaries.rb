class AddDiscardedAtToDictionaries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # if_not_exists: a dev DB rebuilt while 20260617120016_create_dictionaries briefly declared this
  # column already has it; deployed DBs never ran that edit and get it here.
  def change
    add_column :dictionaries, :discarded_at, :datetime, if_not_exists: true
    add_index :dictionaries, :discarded_at, algorithm: :concurrently, if_not_exists: true
  end
end
