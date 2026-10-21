class AddZoneNameSnapshotToManifests < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_table :manifests, bulk: true do |t|
        t.string :zone_name # Denormalized snapshot
      end
    end
  end
end
