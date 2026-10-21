class RemoveReferenceIdFromDictionaries < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :dictionaries, :reference_id
      remove_column :dictionaries, :reference_id, :string, null: false
    end
  end
end
