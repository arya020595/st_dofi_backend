class MigrateCompaniesCaptainsToCompaniesCrews < ActiveRecord::Migration[8.1]
  class MigrationCompaniesCaptain < ActiveRecord::Base
    self.table_name = "companies_captains"
  end

  class MigrationCompaniesCrew < ActiveRecord::Base
    self.table_name = "companies_crews"
  end

  class MigrationPosition < ActiveRecord::Base
    self.table_name = "positions"
  end

  # CompaniesCaptain never captured gender or foreign-worker-license data (fields CompaniesCrew
  # requires); pre-launch dev/mock data only, so placeholders are acceptable here. Real captain
  # profiles created going forward go through the normal CompaniesCrew profiling form, which collects
  # these fields properly.
  PLACEHOLDER_GENDER = "Male".freeze
  PLACEHOLDER_LICENSE_NO = "N/A".freeze

  def up
    boat_captain = MigrationPosition.find_or_create_by!(name: "Boat Captain") { |p| p.category = "Crew" }

    MigrationCompaniesCaptain.reset_column_information
    MigrationCompaniesCaptain.find_each do |captain|
      MigrationCompaniesCrew.find_or_create_by!(company_profile_id: captain.company_profile_id,
                                                ic_number: captain.ic_number) do |crew|
        crew.crew_name = captain.captain_name
        crew.passport_number = captain.passport_number
        crew.date_of_birth = captain.date_of_birth
        crew.nationality = captain.nationality
        crew.gender = PLACEHOLDER_GENDER
        crew.position_id = boat_captain.id
        crew.status = "active"
        crew.approval_status = captain.approval_status
        crew.approved_at = captain.approved_at
        crew.approved_by_id = captain.approved_by_id
        crew.amendment_remarks = captain.amendment_remarks
        crew.discarded_at = captain.discarded_at
        crew.foreign_worker_license_no = PLACEHOLDER_LICENSE_NO
        crew.foreign_worker_license_start_date = Date.current
        crew.foreign_worker_license_end_date = 100.years.from_now.to_date
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
