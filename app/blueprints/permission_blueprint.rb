class PermissionBlueprint < Blueprinter::Base
  identifier :id

  fields :code, :name, :platform_scope
end
