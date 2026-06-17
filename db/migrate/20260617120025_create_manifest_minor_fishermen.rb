class CreateManifestMinorFishermen < ActiveRecord::Migration[8.1]
  def change
    create_table :manifest_minor_fishermen, id: :uuid do |t|
      t.references :manifest, null: false, foreign_key: true, type: :uuid
      t.string :full_name, null: false
      t.date :date_of_birth, null: false
      t.string :gender, null: false # male | female
      t.string :relationship_with_owner, null: false # e.g., "Son", "Daughter", "Nephew"

      t.timestamps
    end
  end
end
