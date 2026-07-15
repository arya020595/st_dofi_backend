class ManifestHistoryBlueprint < Blueprinter::Base
  identifier :id

  fields :action, :status_type, :from_state, :to_state, :remarks, :changed_by_id, :created_at
end
