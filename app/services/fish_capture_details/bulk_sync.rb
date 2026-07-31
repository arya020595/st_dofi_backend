module FishCaptureDetails
  class BulkSync
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # Client-generated UUIDs make re-syncing the same offline row idempotent (find_or_initialize by
    # that id). A row whose id already belongs to a DIFFERENT capture report is rejected per-row
    # rather than aborting the whole batch, so one bad row doesn't block the rest of the sync.
    def call(capture_report, records)
      Success(Array(records).map { |attributes| sync_one(capture_report, attributes) })
    end

    private

    def sync_one(capture_report, attributes)
      local_id = attributes[:id]
      existing = FishCaptureDetail.find_by(id: local_id) if local_id.present?
      return collision_result(local_id) if existing && existing.capture_report_id != capture_report.id

      detail = existing || capture_report.fish_capture_details.new(id: local_id)
      persist(detail, attributes)
    end

    def collision_result(local_id)
      { id: local_id, status: "fail", errors: ["already belongs to a different capture report"] }
    end

    def synced_attributes(attributes)
      dictionary = Dictionary.find_by(id: attributes[:dictionary_id])
      price = attributes[:price_per_kg].to_f
      amount = attributes[:amount_captured_kg].to_f

      attributes.slice(:fishing_gear_detail_id, :dictionary_id, :fish_type, :price_per_kg, :amount_captured_kg).merge(
        local_name: dictionary&.local_name, scientific_name: dictionary&.scientific_name,
        overall_total: price * amount, synced_at: Time.current
      )
    end

    def persist(detail, attributes)
      unless valid_gear_detail?(detail.capture_report, attributes[:fishing_gear_detail_id])
        return invalid_gear_result(attributes[:id])
      end

      detail.assign_attributes(synced_attributes(attributes))

      if detail.save
        { id: detail.id, status: "success" }
      else
        { id: attributes[:id], status: "fail", errors: detail.errors.full_messages }
      end
    end

    def valid_gear_detail?(capture_report, gear_detail_id)
      gear_detail_id.present? && capture_report.fishing_gear_details.exists?(id: gear_detail_id)
    end

    def invalid_gear_result(local_id)
      {
        id: local_id,
        status: "fail",
        errors: ["fishing_gear_detail_id must reference a fishing gear detail on this capture report"]
      }
    end
  end
end
