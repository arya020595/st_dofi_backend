class AdminAccountBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :email, :username, :registration_type, :designation, :unit, :position,
         :contact_no, :fisherman_status, :rejection_reason, :revoked_at, :created_at, :updated_at

  field :category do |user|
    user.fisherman? ? "fisherman_account" : "jetty_manager_account"
  end

  field :status, &:lifecycle_status
  association :role, blueprint: RoleBlueprint
  association :company_profile, blueprint: CompanyProfileBlueprint
end
