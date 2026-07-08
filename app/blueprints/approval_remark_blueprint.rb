class ApprovalRemarkBlueprint < Blueprinter::Base
  identifier :id

  fields :reference_id, :name, :discarded_at, :created_at, :updated_at
end
