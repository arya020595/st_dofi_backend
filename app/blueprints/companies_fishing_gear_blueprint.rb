class CompaniesFishingGearBlueprint < Blueprinter::Base
  identifier :id

  fields :local_name, :quantity, :usage_value, :approval_status, :amendment_remarks, :company_profile_id,
         :fishing_gear_id, :companies_vessel_id, :discarded_at, :created_at, :updated_at

  association :fishing_gear, blueprint: FishingGearBlueprint
end
