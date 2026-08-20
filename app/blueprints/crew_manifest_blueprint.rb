class CrewManifestBlueprint < Blueprinter::Base
  identifier :id

  fields :crew_name, :ic_number, :passport_number, :nationality, :date_of_birth,
         :companies_crew_id, :created_at

  field :position do |crew_manifest|
    snapshot_position = crew_manifest.position
    next snapshot_position if snapshot_position.present? && !snapshot_position.start_with?("#<")

    crew_manifest.companies_crew&.position&.name
  end
end
