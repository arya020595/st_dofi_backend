class RemoveReferenceIdFromNationalities < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :nationalities, :reference_id
      remove_column :nationalities, :reference_id, :string
    end
  end
end
