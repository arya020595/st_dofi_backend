class CompanyProfileBlueprint < Blueprinter::Base
  identifier :id

  fields :registration_type, :company_name, :rocbn_no
end
