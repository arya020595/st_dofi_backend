class FishermanApprovalDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :registration_type, :designation, :status, :rejection_reason, :created_at, :updated_at

  field(:approval_status, &:approval_status_label)

  association :company_profile, blueprint: CompanyProfileBlueprint
  association(:owner_profile, blueprint: CompanyProfileContactBlueprint) { |user| user.company_profile&.owner_contact }
  association(:admin_profile, blueprint: CompanyProfileContactBlueprint) { |user| user.company_profile&.admin_contact }
end
