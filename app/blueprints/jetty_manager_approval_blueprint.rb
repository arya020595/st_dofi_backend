class JettyManagerApprovalBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :unit, :position, :contact_no, :status, :rejection_reason, :created_at, :updated_at

  field(:approval_status, &:approval_status_label)
end
