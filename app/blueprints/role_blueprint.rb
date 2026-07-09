class RoleBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :name, :description, :created_at, :updated_at

  association :permissions, blueprint: PermissionBlueprint
end
