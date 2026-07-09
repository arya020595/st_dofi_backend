class RemoveReferenceIdFromFishingGears < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :fishing_gears, :reference_id
      remove_column :fishing_gears, :reference_id, :string, null: false
    end
  end
end
