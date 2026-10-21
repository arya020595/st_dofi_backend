class ValidateCaptainCrewForeignKeyOnManifests < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :manifests, :companies_crews, column: :captain_crew_id
  end
end
