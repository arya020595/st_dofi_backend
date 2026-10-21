module CaptureReports
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, attributes)
      report.manifest.with_lock do
        report.reload
        unless report.editable?
          report.errors.add(:base, "Verified capture reports cannot be modified")
          next Failure(report)
        end

        report.update(attributes) ? Success(report) : Failure(report)
      end
    end
  end
end
