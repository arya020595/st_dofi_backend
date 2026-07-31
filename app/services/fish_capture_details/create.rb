module FishCaptureDetails
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(capture_report, attributes)
      dictionary = Dictionary.find_by(id: attributes[:dictionary_id])
      detail = capture_report.fish_capture_details.new
      gear_detail = eligible_gear_detail(capture_report, attributes[:fishing_gear_detail_id])
      return invalid_gear_detail(detail) if gear_detail.nil?

      detail.assign_attributes(build_attributes(attributes, dictionary, gear_detail))
      return Failure(detail) unless detail.save

      Success(detail)
    end

    private

    def build_attributes(attributes, dictionary, gear_detail)
      attributes.merge(
        fishing_gear_detail: gear_detail,
        local_name: dictionary&.local_name,
        scientific_name: dictionary&.scientific_name,
        overall_total: overall_total(attributes),
        synced_at: Time.current
      )
    end

    def eligible_gear_detail(capture_report, gear_detail_id)
      return if gear_detail_id.blank?

      capture_report.fishing_gear_details.find_by(id: gear_detail_id)
    end

    def invalid_gear_detail(detail)
      detail.errors.add(:fishing_gear_detail_id, "must reference a fishing gear detail on this capture report")
      Failure(detail)
    end

    def overall_total(attributes)
      attributes[:price_per_kg].to_f * attributes[:amount_captured_kg].to_f
    end
  end
end
