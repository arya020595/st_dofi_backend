module CaptureReports
  class Resubmit
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:)
      Transition.call(report, :resubmit, actor: actor).tap do |result|
        next unless result.success?

        Notifications::ManifestPublisher.call(
          event: :capture_report_resubmitted,
          manifest: report.manifest,
          capture_report: report
        )
      end
    end
  end
end
