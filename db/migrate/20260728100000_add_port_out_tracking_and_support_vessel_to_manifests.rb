class AddPortOutTrackingAndSupportVesselToManifests < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # PostgreSQL 11+ stores immutable constant defaults in the catalog, so these additions do not
    # rewrite the existing manifests table. Strong Migrations cannot inspect a change_table block.
    safety_assured do
      change_table :manifests, bulk: true do |t|
        t.boolean :ais_tracking, null: false, default: false
        t.boolean :has_support_vessel, null: false, default: false
      end
    end

    add_reference :manifests, :support_vessel, type: :uuid, index: { algorithm: :concurrently }
  end
end
