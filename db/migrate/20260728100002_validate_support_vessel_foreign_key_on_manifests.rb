class ValidateSupportVesselForeignKeyOnManifests < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :manifests, :companies_vessels, column: :support_vessel_id
  end
end
