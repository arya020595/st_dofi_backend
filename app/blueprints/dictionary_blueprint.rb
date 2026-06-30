class DictionaryBlueprint < Blueprinter::Base
  identifier :id

  fields :reference_id, :local_name, :scientific_name, :group_name, :family_name, :created_at, :updated_at

  field :image_url do |dictionary|
    next nil unless dictionary.image.attached?

    dictionary.image.url
  rescue CloudinaryException, ActiveStorage::Error => e
    Rails.logger.error("Dictionary##{dictionary.id} image URL generation failed: #{e.message}")
    nil
  end
end
