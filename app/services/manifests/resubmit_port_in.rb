module Manifests
  class ResubmitPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return resubmit_capture_reports(manifest, actor: actor) if capture_report_amendment_resubmittable?(manifest)
      return Failure(manifest) unless manifest.may_resubmit_port_in?

      manifest.resubmit_port_in!(actor: actor)
      Success(manifest)
    end

    private

    def capture_report_amendment_resubmittable?(manifest)
      manifest.capture_report_submitted? &&
        manifest.port_in_pending? &&
        manifest.capture_reports.any?(&:needs_amendment?)
    end

    def resubmit_capture_reports(manifest, actor:)
      ActiveRecord::Base.transaction do
        manifest.capture_reports.select(&:needs_amendment?).each do |report|
          CaptureReports::Resubmit.call(report, actor: actor).value!
        end
      end

      Success(manifest)
    end
  end
end
