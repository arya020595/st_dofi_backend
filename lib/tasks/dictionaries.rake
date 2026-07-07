namespace :dictionaries do
  desc "Copy Dictionary image blobs to the minio Active Storage service. Idempotent — only " \
       "touches blobs not already on minio. Pass DRY_RUN=1 to preview without writing."
  task migrate_images_to_minio: :environment do
    target_service_name = "minio"
    target_service = ActiveStorage::Blob.services.fetch(target_service_name)
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil))

    blobs = ActiveStorage::Blob.where.not(service_name: target_service_name)
    puts "Found #{blobs.count} blob(s) not yet on '#{target_service_name}'#{' (dry run)' if dry_run}."

    blobs.find_each do |blob|
      if dry_run
        puts "[dry run] #{blob.filename} (blob ##{blob.id}): #{blob.service_name} -> #{target_service_name}"
        next
      end

      original_service_name = blob.service_name
      blob.open do |file|
        target_service.upload(blob.key, file, checksum: blob.checksum, content_type: blob.content_type)
      end
      blob.update!(service_name: target_service_name)
      puts "Migrated #{blob.filename} (blob ##{blob.id}): #{original_service_name} -> #{target_service_name}"
    end

    puts "Done." unless dry_run
  end
end
