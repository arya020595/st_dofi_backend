class CaptureReportVerificationPolicy < ApplicationPolicy
  def verify? = permitted?("verify")
  def request_amendment? = permitted?("request_amendment")

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def permission_resource = "capture_report_verifications"
end
