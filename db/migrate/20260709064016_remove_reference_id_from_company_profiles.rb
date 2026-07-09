class RemoveReferenceIdFromCompanyProfiles < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :company_profiles, :reference_id
      remove_column :company_profiles, :reference_id, :string, null: false
    end
  end
end
