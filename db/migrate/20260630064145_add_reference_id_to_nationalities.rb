class AddReferenceIdToNationalities < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :nationalities, :reference_id, :string
    add_index :nationalities, :reference_id, unique: true, algorithm: :concurrently
  end
end
