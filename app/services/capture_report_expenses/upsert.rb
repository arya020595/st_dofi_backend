module CaptureReportExpenses
  class Upsert
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(capture_report, attributes)
      expense = capture_report.capture_report_expense || capture_report.build_capture_report_expense
      return Success(expense) if expense.update(attributes)

      Failure(expense)
    end
  end
end
