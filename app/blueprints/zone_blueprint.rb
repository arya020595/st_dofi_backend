class ZoneBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :start_range, :end_range, :created_at, :updated_at
end
