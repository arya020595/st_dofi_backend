class NationalityBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :code, :is_local_citizenship, :created_at, :updated_at
end
