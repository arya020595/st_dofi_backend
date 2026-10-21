class RemoveReferenceIdFromPositions < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :positions, :reference_id
      remove_column :positions, :reference_id, :string
    end
  end
end
