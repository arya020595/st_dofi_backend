class CreateCrewManifests < ActiveRecord::Migration[8.1]
  def change
    create_table :crew_manifests, id: :uuid do |t|
      t.references :manifest, null: false, foreign_key: true, type: :uuid
      t.references :companies_crew, foreign_key: true, type: :uuid
      t.string :crew_name # Snapshot at time of manifest creation
      t.string :ic_number # IC/Passport No. shown in crew table
      t.string :passport_number
      t.date :date_of_birth # D.O.B shown in crew table
      t.string :position # "Crew Staff", "Captain", from positions master data
      t.string :nationality # "Bruneian", "Argentine" etc.

      t.timestamps
    end
  end
end
