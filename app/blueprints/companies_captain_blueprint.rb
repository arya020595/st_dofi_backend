class CompaniesCaptainBlueprint < Blueprinter::Base
  identifier :id

  fields :captain_name, :date_of_birth, :ic_number, :passport_number, :nationality,
         :approval_status, :amendment_remarks, :company_profile_id, :discarded_at, :created_at, :updated_at
end
