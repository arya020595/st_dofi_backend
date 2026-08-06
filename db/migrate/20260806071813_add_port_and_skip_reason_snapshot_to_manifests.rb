class AddPortAndSkipReasonSnapshotToManifests < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_table :manifests, bulk: true do |t|
        t.string :port_out_name # Denormalized snapshot
        t.string :port_in_name
        t.string :skip_reason_name
      end
    end
  end
end
