class CaptureReportPolicy < ApplicationPolicy
  RESOURCE = "capture_reports".freeze
  VERIFICATIONS = "capture_report_verifications".freeze

  def index? = user.permission?("#{RESOURCE}.list")
  def show? = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def resubmit? = user.permission?("#{RESOURCE}.resubmit")
  def verify? = user.permission?("#{VERIFICATIONS}.verify")
  def request_amendment? = user.permission?("#{VERIFICATIONS}.amendment")

  class Scope < Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(:manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end
end
