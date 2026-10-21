class AddCaptainCrewIdToManifests < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_reference :manifests, :captain_crew, type: :uuid, index: { algorithm: :concurrently }

    # Maps each manifest's old companies_captain_id to the CompaniesCrew row that
    # MigrateCompaniesCaptainsToCompaniesCrews created for that same captain (matched on
    # ic_number + company_profile_id, the natural key preserved across the migration).
    safety_assured do
      execute <<~SQL.squish
        UPDATE manifests
        SET captain_crew_id = matched_crew.id
        FROM companies_captains AS cap
        JOIN companies_crews AS matched_crew
          ON matched_crew.ic_number = cap.ic_number AND matched_crew.company_profile_id = cap.company_profile_id
        WHERE manifests.companies_captain_id = cap.id
      SQL
    end
  end

  def down
    remove_reference :manifests, :captain_crew, index: { algorithm: :concurrently }
  end
end
