module Manifests
  class SetCrew
    def self.call(...) = new.call(...)

    # Replace-all-on-save: the crew list is resubmitted as a whole document with the manifest
    # (Flow 1), not managed as independently created/destroyed rows.
    def call(manifest, crew_ids: [], ad_hoc_crew: [])
      manifest.crew_manifests.destroy_all
      Array(crew_ids).each { |id| snapshot_from_companies_crew(manifest, id) }
      Array(ad_hoc_crew).each { |attributes| manifest.crew_manifests.create!(attributes) }
      manifest
    end

    private

    def snapshot_from_companies_crew(manifest, crew_id)
      crew = CompaniesCrew.kept.approved.find(crew_id)
      manifest.crew_manifests.create!(
        companies_crew: crew,
        crew_name: crew.crew_name,
        ic_number: crew.ic_number,
        passport_number: crew.passport_number,
        date_of_birth: crew.date_of_birth,
        position: crew.position,
        nationality: crew.nationality
      )
    end
  end
end
