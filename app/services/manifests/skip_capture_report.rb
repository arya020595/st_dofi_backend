module Manifests
  class SkipCaptureReport
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, skip_reason_id:, remarks: nil, **)
      manifest.with_lock { skip_report(manifest, skip_reason_id, remarks) }
    end

    private

    def skip_report(manifest, skip_reason_id, remarks)
      return not_at_sea(manifest) unless manifest.at_sea?

      reason = ManifestSkipReason.kept.find_by(id: skip_reason_id)
      return invalid_reason(manifest) if reason.nil?

      skipped = manifest.update(capture_report_skipped: true, skip_reason: reason, skip_reason_name: reason.name,
                                skip_reason_remarks: remarks)
      skipped ? Success(manifest) : Failure(manifest)
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
