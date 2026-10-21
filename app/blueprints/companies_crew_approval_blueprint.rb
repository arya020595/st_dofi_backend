class CompaniesCrewApprovalBlueprint < Blueprinter::Base
  identifier :id

  fields :crew_name, :date_of_birth, :ic_number, :passport_number, :position_id, :nationality, :gender, :status,
         :foreign_worker_license_no, :foreign_worker_license_start_date, :foreign_worker_license_end_date,
         :approval_status, :amendment_remarks, :company_profile_id, :created_at, :updated_at

  association :position, blueprint: PositionBlueprint
end
