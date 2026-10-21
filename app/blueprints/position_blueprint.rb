class PositionBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :category, :created_at, :updated_at
end
