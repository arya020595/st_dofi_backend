class EntityUserIndividualFishermanBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :created_at

  field :type do |user|
    user.company_profile.registration_type
  end

  field :position do |user|
    user.position.presence || user.designation.presence || user.role&.name
  end

  field :status, &:lifecycle_status
end
