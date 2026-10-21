class CompaniesFishingGearApprovalBlueprint < Blueprinter::Base
  identifier :id

  fields :local_name, :quantity, :usage_value, :approval_status, :amendment_remarks, :company_profile_id,
         :fishing_gear_id, :fishing_gear_name, :fishing_gear_type, :fishing_gear_fee, :companies_vessel_id,
         :created_at, :updated_at

  association :fishing_gear, blueprint: FishingGearBlueprint
end
