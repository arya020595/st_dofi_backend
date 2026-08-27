class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email, :employee_id, :username, :fisherman_status, :preferred_locale, :unit, :position, :contact_no,
         :designation, :registration_type, :rejection_reason, :created_at, :updated_at

  field(:status, &:lifecycle_status)

  association :role, blueprint: RoleBlueprint
  association :company_profile, blueprint: CompanyProfileBlueprint
  association :company_profile_contact, blueprint: CompanyProfileContactBlueprint
end
