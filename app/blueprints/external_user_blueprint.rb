class ExternalUserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :email, :username, :registration_type, :designation, :unit, :position,
         :contact_no, :created_at, :updated_at

  field :status
  association :role, blueprint: RoleBlueprint
  association :company_profile, blueprint: CompanyProfileBlueprint
end
