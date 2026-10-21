class EntityUserCompanyBlueprint < Blueprinter::Base
  identifier :id

  fields :company_name, :registration_type, :updated_at

  field :user_count, &:entity_user_count
end
