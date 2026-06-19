class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email, :employee_id, :status, :preferred_locale, :unit, :position,
         :registration_type, :created_at, :updated_at

  association :role, blueprint: RoleBlueprint
end
