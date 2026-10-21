class RemoveReferenceIdFromPorts < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :ports, :reference_id
      remove_column :ports, :reference_id, :string, null: false
    end
  end
end
