class ManifestSupportVesselBlueprint < Blueprinter::Base
  identifier :id

  fields :companies_vessel_id, :vessel_name, :boat_number, :registration_no, :created_at, :updated_at
end
