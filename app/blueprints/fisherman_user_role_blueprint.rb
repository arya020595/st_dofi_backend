class FishermanUserRoleBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :name, :description, :platform_scope, :company_profile_id, :is_default, :created_at, :updated_at
end
