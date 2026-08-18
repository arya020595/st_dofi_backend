module Manifests
  class SkipCaptureReport
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, skip_reason_id:, remarks: nil, actor: nil)
      return not_at_sea(manifest) unless manifest.at_sea?

      reason = ManifestSkipReason.kept.find_by(id: skip_reason_id)
      return invalid_reason(manifest) if reason.nil?

      ActiveRecord::Base.transaction do
        manifest.update!(capture_report_skipped: true, skip_reason: reason, skip_reason_name: reason.name,
                         skip_reason_remarks: remarks)
        auto_complete_port_in!(manifest, actor: actor)
      end

      Success(manifest)
    end

    private

    def auto_complete_port_in!(manifest, actor:)
      record_port_in_history!(manifest, actor: actor)
      record_manifest_history!(manifest, actor: actor)

      manifest.update!(
        port_in_status: "approved",
        manifest_status: "completed",
        port_in_datetime: Time.current,
        port_in_amendment_remarks: nil,
        capture_report_amendment_remarks: nil
      )
    end

    def record_port_in_history!(manifest, actor:)
      record_status_history!(
        manifest: manifest,
        actor: actor,
        status_type: "port_in_status",
        action: "skip_capture_report_auto_approve_port_in!",
        from_state: manifest.port_in_status,
        to_state: "approved"
      )
    end

    def record_manifest_history!(manifest, actor:)
      record_status_history!(
        manifest: manifest,
        actor: actor,
        status_type: "manifest_status",
        action: "skip_capture_report_auto_complete_manifest!",
        from_state: manifest.manifest_status,
        to_state: "completed"
      )
    end

    def record_status_history!(manifest:, actor:, **attributes)
      ManifestHistory.create!(
        manifest: manifest,
        changed_by_id: actor&.id,
        **attributes
      )
    end

    def not_at_sea(manifest)
      manifest.errors.add(:base, "Capture report can only be skipped while the manifest is at sea")
      Failure(manifest)
    end

    def invalid_reason(manifest)
      manifest.errors.add(:skip_reason_id, "is invalid")
      Failure(manifest)
    end
  end
end
