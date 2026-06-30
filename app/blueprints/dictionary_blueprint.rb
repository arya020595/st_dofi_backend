class DictionaryBlueprint < Blueprinter::Base
  identifier :id

  fields :reference_id, :local_name, :scientific_name, :group_name, :family_name, :created_at, :updated_at

  field :image_url do |dictionary|
    dictionary.image.attached? ? dictionary.image.url : nil
  end
end
