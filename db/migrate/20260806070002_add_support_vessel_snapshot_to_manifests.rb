class AddSupportVesselSnapshotToManifests < ActiveRecord::Migration[8.1]
  def change
    change_table :manifests, bulk: true do |t|
      t.string :support_vessel_name # Denormalized snapshot
      t.string :support_vessel_no
    end
  end
end
