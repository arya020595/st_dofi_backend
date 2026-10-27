def migrate_dictionary_blob!(blob, target_service, target_service_name, dry_run:)
  if dry_run
    puts "[dry run] #{blob.filename} (blob ##{blob.id}): #{blob.service_name} -> #{target_service_name}"
    return
  end

  original_service_name = blob.service_name
  blob.open do |file|
    target_service.upload(blob.key, file, checksum: blob.checksum, content_type: blob.content_type)
  end
  blob.update!(service_name: target_service_name)
  puts "Migrated #{blob.filename} (blob ##{blob.id}): #{original_service_name} -> #{target_service_name}"
end

namespace :dictionaries do
  desc "Copy Dictionary image blobs to the default Active Storage service (the private bucket). " \
       "Idempotent — only touches blobs not already there. Pass DRY_RUN=1 to preview without writing."
  task migrate_images_to_minio: :environment do
    target_service_name = Rails.application.config.active_storage.service.to_s
    target_service = ActiveStorage::Blob.services.fetch(target_service_name)
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil))

    # Scoped to Dictionary's own image attachments specifically, not every blob in the app — other
    # models may legitimately target a different service (e.g. the private bucket).
    blobs = ActiveStorage::Blob.joins(:attachments)
                               .where(active_storage_attachments: { record_type: "Dictionary", name: "image" })
                               .where.not(service_name: target_service_name)
                               .distinct
    puts "Found #{blobs.count} Dictionary image blob(s) not yet on '#{target_service_name}'#{' (dry run)' if dry_run}."

    blobs.find_each { |blob| migrate_dictionary_blob!(blob, target_service, target_service_name, dry_run:) }

    puts "Done." unless dry_run
  end
end
