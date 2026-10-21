class CompaniesVesselApprovalBlueprint < Blueprinter::Base
  identifier :id

  fields :vessel_name, :boat_number, :capacity, :license_reg_date, :license_expiry_date, :status,
         :category, :registration_no, :max_crew, :gross_tonnage, :length, :horse_power, :year_built,
         :draft, :material, :is_powered, :charter_type, :boat_type, :engine_count, :approval_status,
         :amendment_remarks, :company_profile_id, :zone_id, :created_at, :updated_at
end
