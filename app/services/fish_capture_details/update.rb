module FishCaptureDetails
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(detail, attributes)
      return invalid_gear_detail(detail) unless valid_gear_detail?(detail, attributes[:fishing_gear_detail_id])

      price = (attributes[:price_per_kg] || detail.price_per_kg).to_f
      amount = (attributes[:amount_captured_kg] || detail.amount_captured_kg).to_f
      dictionary = Dictionary.find_by(id: attributes[:dictionary_id]) if attributes[:dictionary_id].present?
      update_attributes = attributes.merge(overall_total: price * amount)
      update_attributes[:local_name] = dictionary&.local_name if attributes[:dictionary_id].present?
      update_attributes[:scientific_name] = dictionary&.scientific_name if attributes[:dictionary_id].present?
      update_attributes[:synced_at] = Time.current
      return Success(detail) if detail.update(update_attributes)

      Failure(detail)
    end

    private

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
