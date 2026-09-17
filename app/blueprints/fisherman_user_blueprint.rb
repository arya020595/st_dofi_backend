class FishermanUserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email, :employee_id, :username, :normalized_ic_number, :status, :fisherman_status,
         :preferred_locale, :unit, :position, :contact_no, :designation, :registration_type, :rejection_reason,
         :created_at, :updated_at

  association :role, blueprint: FishermanUserRoleBlueprint
  association :company_profile_contact, blueprint: CompanyProfileContactBlueprint
end
