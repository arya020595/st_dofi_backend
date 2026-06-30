class FishingGearBlueprint < Blueprinter::Base
  identifier :id

  fields :reference_id, :local_name, :name, :gear_type, :unit, :size, :fee, :created_at, :updated_at
end
