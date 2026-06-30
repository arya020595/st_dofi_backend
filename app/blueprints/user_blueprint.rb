class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email, :employee_id, :status, :preferred_locale, :unit, :position, :contact_no, :designation,
         :registration_type, :created_at, :updated_at

  association :role, blueprint: RoleBlueprint
  association :company_profile, blueprint: CompanyProfileBlueprint
end
