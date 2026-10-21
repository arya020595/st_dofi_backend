class CreateManifestSupportVessels < ActiveRecord::Migration[8.1]
  def change
    create_table :manifest_support_vessels, id: :uuid do |t|
      t.references :manifest, null: false, type: :uuid, foreign_key: true
      t.references :companies_vessel, null: false, type: :uuid, foreign_key: true
      t.string :vessel_name, null: false
      t.string :boat_number, null: false
      t.string :registration_no

      t.timestamps
    end

    add_index :manifest_support_vessels, %i[manifest_id companies_vessel_id], unique: true,
                                                                              name: "index_msv_on_manifest_and_vessel"

    reversible do |direction|
      direction.up do
        safety_assured do
          execute <<~SQL.squish
            INSERT INTO manifest_support_vessels
              (id, manifest_id, companies_vessel_id, vessel_name, boat_number, registration_no, created_at, updated_at)
            SELECT gen_random_uuid(), manifests.id, companies_vessels.id, companies_vessels.vessel_name,
                   companies_vessels.boat_number, companies_vessels.registration_no, NOW(), NOW()
            FROM manifests
            INNER JOIN companies_vessels ON companies_vessels.id = manifests.support_vessel_id
            WHERE manifests.support_vessel_id IS NOT NULL
          SQL
        end
      end
    end
  end
end
