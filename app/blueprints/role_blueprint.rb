class RoleBlueprint < Blueprinter::Base
  identifier :id

  fields :reference_id, :name, :description, :created_at, :updated_at

  association :permissions, blueprint: PermissionBlueprint
end
