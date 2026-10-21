class RemoveCompaniesCaptainIdFromManifests < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_reference :manifests, :companies_captain, foreign_key: true, type: :uuid
    end
  end
end
