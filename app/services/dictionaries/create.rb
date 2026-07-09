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

    def build_all(entries)
      entries.map do |attrs|
        image = attrs.delete(:image)
        Dictionary.new(attrs).tap do |d|
          d.image.attach(uploaded_blob_for(image)) if image.present?
        end
      end
    end

    # Uploads eagerly (rather than relying on ActiveStorage's default after_commit upload) so a
    # storage failure surfaces before any Dictionary row is persisted — otherwise the row commits
    # first and an upload failure afterward leaves an orphaned, image-less record behind.
    def uploaded_blob_for(image)
      io = image.respond_to?(:open) ? image.open : image
      ActiveStorage::Blob.create_and_upload!(io: io, filename: image.original_filename,
                                             content_type: image.content_type)
    end
  end
end
