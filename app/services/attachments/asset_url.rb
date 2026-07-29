module Attachments
  class AssetUrl
    # For the public-read bucket (see docs/minio/MINIO.md §2): no signature, no expiry, no redirect
    # through Rails — the bucket already grants anonymous GetObject, so this is a stable, directly
    # cacheable URL. Distinct from Attachments::PublicUrl, which presigns for the private bucket.
    def self.call(blob)
      service = if blob.service_name == "minio_assets"
                  ActiveStorage::Blob.services.fetch(:minio_assets_public)
                else
                  blob.service
                end
      service.url(blob.key, expires_in: nil, disposition: "inline", filename: blob.filename,
                            content_type: blob.content_type)
    end
  end
end
