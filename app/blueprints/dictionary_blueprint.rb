class DictionaryBlueprint < Blueprinter::Base
  identifier :id

  fields :local_name, :scientific_name, :group_name, :family_name, :created_at, :updated_at

  field :image_url do |dictionary|
    next nil unless dictionary.image.attached?

    public_url_for(dictionary.image.blob)
  rescue CloudinaryException, ActiveStorage::Error, Aws::Errors::ServiceError => e
    Rails.logger.error("Dictionary##{dictionary.id} image URL generation failed: #{e.message}")
    nil
  end

  # MinIO's endpoint (config/storage.yml's `minio:` block) is an internal Docker address a
  # browser can't reach (see docs/MINIO.md). Sign against `minio_public` instead, which shares
  # the same bucket/credentials but points at the reverse-proxied public endpoint. Presigning is
  # a local computation, not a network call, so this never actually talks to `minio_public`.
  def self.public_url_for(blob)
    service = blob.service_name == "minio" ? ActiveStorage::Blob.services.fetch(:minio_public) : blob.service
    service.url(blob.key, expires_in: 5.minutes, disposition: "inline", filename: blob.filename,
                          content_type: blob.content_type)
  end
end
