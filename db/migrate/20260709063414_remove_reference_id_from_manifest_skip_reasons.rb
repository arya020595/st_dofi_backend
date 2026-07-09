class RemoveReferenceIdFromManifestSkipReasons < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :manifest_skip_reasons, :reference_id
      remove_column :manifest_skip_reasons, :reference_id, :string, null: false
    end
  end
end
