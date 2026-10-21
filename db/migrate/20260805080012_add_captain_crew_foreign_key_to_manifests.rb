class AddCaptainCrewForeignKeyToManifests < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :manifests, :companies_crews, column: :captain_crew_id, validate: false
  end
end
