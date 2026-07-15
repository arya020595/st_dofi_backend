class CompaniesFishingGearBlueprint < Blueprinter::Base
  identifier :id

  fields :local_name, :quantity, :approval_status, :amendment_remarks, :company_profile_id,
         :fishing_gear_id, :discarded_at, :created_at, :updated_at

  association :fishing_gear, blueprint: FishingGearBlueprint
end
