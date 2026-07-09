class CompanyProfileDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :registration_type, :company_name, :company_address, :rocbn_no, :contact_no, :full_name,
         :ic_no, :ic_colour, :gender, :district, :mukim, :village, :full_address, :fisherman_card_no, :issue_date,
         :license_expiry_date, :designation, :worker_quota, :dofi_registration_no, :created_at, :updated_at
end
