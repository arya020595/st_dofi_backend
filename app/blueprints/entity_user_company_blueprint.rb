class EntityUserCompanyBlueprint < Blueprinter::Base
  identifier :id

  fields :company_name, :registration_type, :updated_at

  field :user_count do |company_profile|
    company_profile.read_attribute(:entity_user_count).to_i
  end
end
