class ManifestExpenseBlueprint < Blueprinter::Base
  identifier :id

  fields :fuel_litres, :fuel_bnd, :ice_litres, :ice_bnd, :ration_bnd, :manifest_id, :created_at, :updated_at
end
