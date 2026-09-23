class ExternalUserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :email, :username, :registration_type, :designation, :unit, :position,
         :contact_no, :rejection_reason, :revoked_at, :created_at, :updated_at

  field :status, &:lifecycle_status
  association :role, blueprint: RoleBlueprint
  association :company_profile, blueprint: CompanyProfileBlueprint
end
