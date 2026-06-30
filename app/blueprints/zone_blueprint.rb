class ZoneBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :zone_type, :start_range, :end_range, :created_at, :updated_at
end
