class CompanyProfileContactBlueprint < Blueprinter::Base
  identifier :id

  fields :full_name, :ic_no, :ic_colour, :gender, :designation, :company_profile_id, :created_at, :updated_at
end
