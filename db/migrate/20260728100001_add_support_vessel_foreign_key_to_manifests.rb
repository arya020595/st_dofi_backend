class AddSupportVesselForeignKeyToManifests < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :manifests, :companies_vessels, column: :support_vessel_id, validate: false
  end
end
