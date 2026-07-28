module CompaniesVessels
  class AttachImages
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, images)
      vessel.images.attach(images)
      return Failure(vessel) unless vessel.valid?

      Success(vessel)
    rescue ActiveStorage::IntegrityError, Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      vessel.errors.add(:images, "could not be uploaded: #{e.message}")
      Failure(vessel)
    end
  end
end
