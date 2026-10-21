module CompaniesVessels
  class AttachImages
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # images: { "front" => file, "back" => file, ... } — each present view replaces that slot.
    def call(vessel, images)
      unknown = images.keys.map(&:to_s) - CompaniesVessel::IMAGE_VIEWS
      return reject_unknown(vessel, unknown) if unknown.any?

      images.each { |view, file| vessel.image_attachment(view).attach(file) }
      vessel.valid? ? Success(vessel) : Failure(vessel)
    rescue ActiveStorage::IntegrityError, Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      vessel.errors.add(:images, "could not be uploaded: #{e.message}")
      Failure(vessel)
    end

    private

    def reject_unknown(vessel, unknown)
      vessel.errors.add(:images, "has unknown view(s): #{unknown.join(', ')}")
      Failure(vessel)
    end
  end
end
