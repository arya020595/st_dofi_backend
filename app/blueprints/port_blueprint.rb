class PortBlueprint < Blueprinter::Base
  identifier :id

  fields :port_name, :latitude, :longitude, :discarded_at, :created_at, :updated_at
end
