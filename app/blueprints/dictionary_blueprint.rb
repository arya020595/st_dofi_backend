class DictionaryBlueprint < Blueprinter::Base
  identifier :id

  fields :local_name, :scientific_name, :group_name, :family_name, :created_at, :updated_at

  # Dictionary images live in the public-read bucket (see docs/MINIO.md §2) — fish-species
  # reference photos aren't sensitive, so this is a direct, stable, unsigned URL rather than our
  # own redirect endpoint. Anyone with the URL can fetch it without going through Rails at all;
  # that's the point of the public tier, not an oversight (contrast Attachments::PublicUrl, used
  # by Api::V1::AttachmentsController for the private bucket).
  field :image_url do |dictionary|
    next nil unless dictionary.image.attached?

    Attachments::AssetUrl.call(dictionary.image.blob)
  end
end
