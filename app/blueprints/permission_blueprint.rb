class PermissionBlueprint < Blueprinter::Base
  identifier :id

  fields :code, :name, :action, :platform_scope, :resource, :section, :section_order, :resource_order,
         :action_order, :resource_label, :section_label
end
