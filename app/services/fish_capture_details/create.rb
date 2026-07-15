module FishCaptureDetails
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(capture_report, attributes)
      dictionary = Dictionary.find_by(id: attributes[:dictionary_id])
      detail = capture_report.fish_capture_details.new(build_attributes(attributes, dictionary))
      return Failure(detail) unless detail.save

      Success(detail)
    end

    private

    def build_attributes(attributes, dictionary)
      attributes.merge(
        local_name: dictionary&.local_name,
        scientific_name: dictionary&.scientific_name,
        overall_total: overall_total(attributes),
        synced_at: Time.current
      )
    end

    def overall_total(attributes)
      attributes[:price_per_kg].to_f * attributes[:amount_captured_kg].to_f
    end
  end
end
