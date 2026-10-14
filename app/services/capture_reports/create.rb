module CaptureReports
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, attributes, actor: nil)
      manifest.with_lock do
        result = create_report(manifest, attributes, actor)
        if result.success? && manifest.capture_report_submitted?
          Notifications::ManifestPublisher.enqueue(event: :capture_report_review_required, manifest:,
                                                   capture_report: result.value!)
        end
        result
      end
    end

    private

    def create_report(manifest, attributes, actor)
      report = manifest.capture_reports.new(attributes)
      if manifest.completed?
        report.errors.add(:base, "Capture reports cannot be added to a completed manifest")
        return Failure(report)
      end
      return Failure(report) unless report.save

      manifest.complete_capture_report!(actor: actor) if manifest.awaiting_port_in_approval?
      Success(report)
    end
  end
end
