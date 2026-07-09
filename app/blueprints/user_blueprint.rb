class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email, :employee_id, :username, :status, :preferred_locale, :unit, :position, :contact_no,
         :designation, :registration_type, :rejection_reason, :created_at, :updated_at

  association :role, blueprint: RoleBlueprint
  association :company_profile, blueprint: CompanyProfileBlueprint
end
