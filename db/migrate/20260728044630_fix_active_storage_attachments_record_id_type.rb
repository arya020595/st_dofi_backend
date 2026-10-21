class FixActiveStorageAttachmentsRecordIdType < ActiveRecord::Migration[8.1]
  # Every table in this app uses uuid primary keys (see any other create_table in db/schema.rb),
  # but the stock `active_storage:install` migration left `record_id` — the polymorphic FK an
  # Attachment uses to point back at its owning record — as bigint. Rails silently truncated every
  # owner's uuid to 0 on write (e.g. "c16b0...".to_i => 0) instead of raising, so every attachment
  # row ever written is indistinguishable from every other one at the DB level: has_one_attached
  # can return the wrong record's file once more than one record of the same type has one attached.
  #
  # Existing rows can't be repaired — the real owner id was never stored, only 0 — so they're
  # purged (deletes the MinIO object too, not just the row) rather than carried forward broken.
  def up
    ActiveStorage::Attachment.find_each(&:purge)

    # strong_migrations flags change_column as a table-rewriting, lock-holding operation on
    # principle — moot here since the table is emptied immediately above by the purge.
    safety_assured do
      remove_index :active_storage_attachments, name: "index_active_storage_attachments_uniqueness"
      # `using:` is only needed to satisfy Postgres' cast-validity check syntactically — the
      # table is empty at this point (purged above), so it never runs against real data.
      change_column :active_storage_attachments, :record_id, :uuid, using: "record_id::text::uuid"
      add_index :active_storage_attachments, %i[record_type record_id name blob_id],
                name: "index_active_storage_attachments_uniqueness", unique: true
    end
  end

  def down
    safety_assured do
      remove_index :active_storage_attachments, name: "index_active_storage_attachments_uniqueness"
      change_column :active_storage_attachments, :record_id, :bigint
      add_index :active_storage_attachments, %i[record_type record_id name blob_id],
                name: "index_active_storage_attachments_uniqueness", unique: true
    end
  end
end
