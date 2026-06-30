module Dictionaries
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(dictionary, attributes)
      return Success(dictionary) if dictionary.update(attributes)

      Failure(dictionary)
    rescue ActiveStorage::IntegrityError, CloudinaryException => e
      dictionary.errors.add(:image, "could not be uploaded: #{e.message}")
      Failure(dictionary)
    end
  end
end
