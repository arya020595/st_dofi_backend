module FishCaptureDetails
  class Destroy
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(detail)
      report = detail.capture_report
      report.manifest.with_lock do
        report.reload
        detail.reload
        unless report.editable?
          detail.errors.add(:base, "Verified capture reports cannot be modified")
          next Failure(detail)
        end

        detail.destroy ? Success(detail) : Failure(detail)
      end
    end
  end
end
