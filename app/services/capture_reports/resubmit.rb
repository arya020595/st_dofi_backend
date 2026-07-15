module CaptureReports
  class Resubmit
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:)
      return Failure(report) unless report.may_resubmit?

      report.resubmit!(actor: actor)
      Success(report)
    end
  end
end
