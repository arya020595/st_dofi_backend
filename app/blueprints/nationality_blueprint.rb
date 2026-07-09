class NationalityBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :code, :created_at, :updated_at
end
