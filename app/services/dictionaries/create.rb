module Dictionaries
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # entries: Array of permitted params hashes, each optionally including :image
    def call(entries)
      dictionaries = build_all(entries)

      invalid = dictionaries.reject(&:valid?)
      return Failure(invalid.first) if invalid.any?

      persist_all(dictionaries)
    rescue ActiveStorage::IntegrityError, CloudinaryException, Aws::Errors::ServiceError,
           Seahorse::Client::NetworkingError => e
      Failure(Dictionary.new.tap { |d| d.errors.add(:image, "could not be uploaded: #{e.message}") })
    end

    private

    def persist_all(dictionaries)
      Dictionary.transaction { dictionaries.each(&:save!) }
      Success(dictionaries)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record)
    end

    # Uploads eagerly, before any Dictionary row is persisted — otherwise the row commits first
    # and a storage failure afterward leaves an orphaned, image-less record behind.
    def build_all(entries)
      entries.map do |attrs|
        image = attrs.delete(:image)
        Dictionary.new(attrs).tap do |d|
          d.image.attach(uploaded_blob_for(image)) if image.present?
        end
      end
    end

    # service_name must match Dictionary's has_one_attached :image service — Attachments::
    # UploadFromParam otherwise has no way to know which of the two buckets this belongs on.
    def uploaded_blob_for(image)
      Attachments::UploadFromParam.call(image, service_name: Rails.application.config.x.active_storage_public_service)
    end
  end
end
