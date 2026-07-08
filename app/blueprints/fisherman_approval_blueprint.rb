class FishermanApprovalBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :registration_type, :status, :rejection_reason, :created_at, :updated_at

  field(:approval_status, &:approval_status_label)
end
