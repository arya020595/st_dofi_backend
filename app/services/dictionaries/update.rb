module Dictionaries
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(dictionary, attributes)
      image = attributes[:image]
      attributes = attributes.merge(image: uploaded_blob_for(image)) if image.present?

      return Success(dictionary) if dictionary.update(attributes)

      Failure(dictionary)
    rescue ActiveStorage::IntegrityError, CloudinaryException, Aws::Errors::ServiceError,
           Seahorse::Client::NetworkingError => e
      dictionary.errors.add(:image, "could not be uploaded: #{e.message}")
      Failure(dictionary)
    end

    private

    # Uploads eagerly (rather than relying on ActiveStorage's default after_commit upload) so a
    # storage failure surfaces before dictionary.update touches the database at all — otherwise
    # the other attribute changes commit first and an upload failure afterward leaves the record
    # partially updated with a broken image reference.
    def uploaded_blob_for(image)
      io = image.respond_to?(:open) ? image.open : image
      ActiveStorage::Blob.create_and_upload!(io: io, filename: image.original_filename,
                                             content_type: image.content_type)
    end
  end
end
