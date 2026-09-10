class PermissionBlueprint < Blueprinter::Base
  identifier :id

  fields :code, :name, :platform_scope, :resource, :section, :section_order, :resource_order,
         :resource_label, :section_label
end
