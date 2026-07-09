class PortBlueprint < Blueprinter::Base
  identifier :id

  fields :port_name, :latitude, :longitude, :created_at, :updated_at
end
