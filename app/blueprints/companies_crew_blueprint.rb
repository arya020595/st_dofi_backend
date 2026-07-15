class CompaniesCrewBlueprint < Blueprinter::Base
  identifier :id

  fields :crew_name, :date_of_birth, :ic_number, :passport_number, :position, :nationality,
         :approval_status, :amendment_remarks, :company_profile_id, :discarded_at, :created_at, :updated_at
end
