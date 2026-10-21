class CompanyProfileBlueprint < Blueprinter::Base
  identifier :id

  fields :profile_number, :registration_type, :company_name, :mailing_address, :rocbn_no, :contact_no
end
