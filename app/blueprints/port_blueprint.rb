class PortBlueprint < Blueprinter::Base
  identifier :id

  fields :reference_id, :port_name, :latitude, :longitude, :created_at, :updated_at
end
