module CompaniesVessels
  class DetachImage
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, view)
      unless CompaniesVessel::IMAGE_VIEWS.include?(view)
        vessel.errors.add(:images, "has unknown view: #{view}")
        return Failure(vessel)
      end

      vessel.image_attachment(view).purge
      Success(vessel)
    rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      vessel.errors.add(:images, "could not be removed: #{e.message}")
      Failure(vessel)
    end
  end
end
