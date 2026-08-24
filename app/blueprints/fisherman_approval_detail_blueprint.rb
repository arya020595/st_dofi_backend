class FishermanApprovalDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :registration_type, :designation, :fisherman_status, :rejection_reason, :created_at,
         :updated_at

  field(:status, &:fisherman_status)
  field(:approval_status, &:fisherman_approval_status_label)

  association :company_profile, blueprint: CompanyProfileBlueprint
  association(:owner_profile, blueprint: CompanyProfileContactBlueprint) { |user| user.company_profile&.owner_contact }
  association(:admin_profile, blueprint: CompanyProfileContactBlueprint) { |user| user.company_profile&.admin_contact }
end
