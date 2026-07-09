class FishermanApprovalDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :registration_type, :designation, :status, :rejection_reason, :created_at, :updated_at

  field(:approval_status, &:approval_status_label)

  association :owner_profile, blueprint: CompanyProfileDetailBlueprint do |user|
    [user.company_profile, user.company_profile&.sibling].compact.find { |profile| profile.designation == "Owner" }
  end

  association :admin_profile, blueprint: CompanyProfileDetailBlueprint do |user|
    [user.company_profile, user.company_profile&.sibling].compact.find { |profile| profile.designation == "Admin" }
  end
end
