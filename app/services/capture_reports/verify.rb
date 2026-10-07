module CaptureReports
  class Verify
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:)
      Transition.call(report, :verify, actor: actor).tap do |result|
        next unless result.success?

        Notifications::ManifestPublisher.call(
          event: :capture_report_verified,
          manifest: report.manifest,
          capture_report: report
        )
      end
    end
  end
end
