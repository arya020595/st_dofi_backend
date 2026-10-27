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

    # Uploads eagerly, before dictionary.update touches the database at all — otherwise the other
    # attribute changes commit first and a storage failure afterward leaves the record partially
    # updated with a broken image reference.
    def uploaded_blob_for(image)
      Attachments::UploadFromParam.call(image)
    end
  end
end
