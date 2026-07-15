class CompaniesVesselApprovalBlueprint < Blueprinter::Base
  identifier :id

  fields :vessel_name, :boat_number, :capacity, :license_reg_date, :license_expiry_date,
         :approval_status, :amendment_remarks, :company_profile_id, :created_at, :updated_at
end
