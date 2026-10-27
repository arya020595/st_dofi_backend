class DictionaryBlueprint < Blueprinter::Base
  identifier :id

  fields :local_name, :scientific_name, :dictionary_group_id, :dictionary_family_id, :created_at, :updated_at

  association :dictionary_group, blueprint: DictionaryGroupBlueprint
  association :dictionary_family, blueprint: DictionaryFamilyBlueprint

  # A relative path to the authenticated attachments endpoint, which relays the bytes: the browser never
  # receives a storage URL (only the backend server may reach the file storage server).
  field :image_url do |dictionary|
    next nil unless dictionary.image.attached?

    Rails.application.routes.url_helpers.api_v1_attachment_path(dictionary.image.blob.signed_id)
  end
end
