module FishCaptureDetails
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(detail, attributes)
      return invalid_gear_detail(detail) unless valid_gear_detail?(detail, attributes[:fishing_gear_detail_id])

      update_attributes = build_update_attributes(detail, attributes)
      return Success(detail) if detail.update(update_attributes)

      Failure(detail)
    end

    private

    def build_update_attributes(detail, attributes)
      dictionary = dictionary_for(attributes[:dictionary_id])
      attributes.merge(
        overall_total: overall_total(detail, attributes),
        local_name: resolved_local_name(detail, dictionary, attributes),
        scientific_name: resolved_scientific_name(detail, dictionary, attributes),
        synced_at: Time.current
      )
    end

    def overall_total(detail, attributes)
      price = (attributes[:price_per_kg] || detail.price_per_kg).to_f
      amount = (attributes[:amount_captured_kg] || detail.amount_captured_kg).to_f

      price * amount
    end

    def dictionary_for(dictionary_id)
      return if dictionary_id.blank?

      Dictionary.find_by(id: dictionary_id)
    end

    def resolved_local_name(detail, dictionary, attributes)
      return detail.local_name if attributes[:dictionary_id].blank?

      dictionary&.local_name
    end

    def resolved_scientific_name(detail, dictionary, attributes)
      return detail.scientific_name if attributes[:dictionary_id].blank?

      dictionary&.scientific_name
    end

    def valid_gear_detail?(detail, gear_detail_id)
      return true if gear_detail_id.blank?

      detail.capture_report.fishing_gear_details.exists?(id: gear_detail_id)
    end

    def invalid_gear_detail(detail)
      detail.errors.add(:fishing_gear_detail_id, "must reference a fishing gear detail on this capture report")
      Failure(detail)
    end
  end
end
