class ManifestApprovalHistoryBlueprint < Blueprinter::Base
  identifier :manifest_id

  fields :status_type, :current_status

  association :histories, blueprint: ManifestHistoryBlueprint
end
