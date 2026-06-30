class AddReferenceIdAndCategoryToPositions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    safety_assured do
      change_table :positions, bulk: true do |t|
        t.string :reference_id
        t.string :category
      end
    end
    add_index :positions, :reference_id, unique: true, algorithm: :concurrently
  end
end
