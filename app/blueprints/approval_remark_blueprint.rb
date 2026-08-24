class ApprovalRemarkBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :usage_scope, :discarded_at, :created_at, :updated_at
end
