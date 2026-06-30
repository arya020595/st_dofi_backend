class NationalityBlueprint < Blueprinter::Base
  identifier :id

  fields :reference_id, :name, :code, :created_at, :updated_at
end
