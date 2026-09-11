class CompanyProfileBlueprint < Blueprinter::Base
  identifier :id

  fields :registration_type, :company_name, :mailing_address, :rocbn_no
end
