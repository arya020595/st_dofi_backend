module Attachments
  class PublicUrl
    EXPIRES_IN = 5.minutes

    # Signs against `minio_public` (reverse-proxied, browser-reachable) instead of the blob's own
    # `minio` service (internal Docker address) — see docs/MINIO.md §2. Falls back to the blob's
    # own service for anything not backed by MinIO (e.g. legacy Cloudinary blobs, Disk in test).
    def self.call(blob, disposition: "inline")
      service = blob.service_name == "minio" ? ActiveStorage::Blob.services.fetch(:minio_public) : blob.service
      service.url(blob.key, expires_in: EXPIRES_IN, disposition:, filename: blob.filename,
                            content_type: blob.content_type)
    end
  end
end
