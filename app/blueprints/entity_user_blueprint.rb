class EntityUserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :ic_number, :created_at

  field :position do |user|
    user.position.presence || user.designation.presence || user.role&.name
  end

  field :status, &:lifecycle_status
end
