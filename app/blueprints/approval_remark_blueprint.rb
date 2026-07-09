class ApprovalRemarkBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :discarded_at, :created_at, :updated_at
end
