class CrewManifestBlueprint < Blueprinter::Base
  identifier :id

  fields :crew_name, :ic_number, :passport_number, :position, :nationality, :date_of_birth,
         :companies_crew_id, :created_at
end
