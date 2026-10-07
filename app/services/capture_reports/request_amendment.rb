module CaptureReports
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:, remarks:)
      Transition.call(report, :request_amendment, actor: actor, remarks: remarks).tap do |result|
        next unless result.success?

        Notifications::ManifestPublisher.call(
          event: :capture_report_amendment_required,
          manifest: report.manifest,
          capture_report: report
        )
      end
    end
  end
end
