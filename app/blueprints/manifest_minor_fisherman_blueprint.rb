class ManifestMinorFishermanBlueprint < Blueprinter::Base
  identifier :id

  fields :full_name, :date_of_birth, :gender, :relationship_with_owner, :manifest_id, :created_at
end
