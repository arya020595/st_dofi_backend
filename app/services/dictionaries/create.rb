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
      # Reserve sequential reference IDs for the whole batch upfront so concurrent
      # bulk inserts don't race on the same max() value inside a transaction.
      next_num = Dictionary.where("reference_id LIKE ?", "SP-%")
                           .maximum("CAST(SUBSTRING(reference_id FROM 4) AS INTEGER)") || 0

      entries.map.with_index(1) do |attrs, offset|
        image = attrs.delete(:image)
        ref_id = format("SP-%04d", next_num + offset)
        Dictionary.new(attrs.merge(reference_id: ref_id)).tap do |d|
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
