module Manifests
  class SubmitPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return not_ready(manifest) unless manifest.capture_report_ready?
      return Failure(manifest) unless manifest.may_submit_port_in?

      ActiveRecord::Base.transaction do
        reset_capture_reports_for_port_in!(manifest)
        manifest.submit_port_in!(actor: actor)
      end

      Success(manifest)
    end

    private

    def reset_capture_reports_for_port_in!(manifest)
      manifest.capture_reports.find_each do |report|
        report.update!(
          capture_report_status: "pending_verification",
          capture_report_remarks: nil,
          reviewed_by_id: nil,
          reviewed_at: nil
        )
      end
    end

    def not_ready(manifest)
      manifest.errors.add(:base, "Capture report must be submitted or skipped before requesting port-in")
      Failure(manifest)
    end
  end
end
