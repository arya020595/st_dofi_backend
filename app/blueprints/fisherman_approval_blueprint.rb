class FishermanApprovalBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :registration_type, :fisherman_status, :rejection_reason, :revoked_at,
         :revocation_comment, :created_at, :updated_at

  field(:status, &:fisherman_status)
  field(:approval_status, &:fisherman_approval_status_label)
end
