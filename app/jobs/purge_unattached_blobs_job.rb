class PurgeUnattachedBlobsJob < ApplicationJob
  UNATTACHED_AFTER = 24.hours

  # Blobs can end up unattached if a record's validation fails after its file was already
  # uploaded (uploads happen eagerly, before save — see docs/MINIO.md §3), or if a client abandons
  # an upload mid-flow. Purging finds these and removes both the DB row and the MinIO object.
  def perform
    ActiveStorage::Blob.unattached
                       .where(active_storage_blobs: { created_at: ...UNATTACHED_AFTER.ago })
                       .find_each(&:purge_later)
  end
end
