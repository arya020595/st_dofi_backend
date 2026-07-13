class CompanyProfileDetailBlueprint < Blueprinter::Base
  identifier :id

  fields :registration_type, :company_name, :company_address, :rocbn_no, :contact_no,
         :district, :mukim, :village, :full_address, :fisherman_card_no, :issue_date,
         :license_expiry_date, :worker_quota, :dofi_registration_no, :created_at, :updated_at

  association :owner_profile, blueprint: CompanyProfileContactBlueprint, &:owner_contact
  association :admin_profile, blueprint: CompanyProfileContactBlueprint, &:admin_contact
end
