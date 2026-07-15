class CaptureReportPolicy < ApplicationPolicy
  RESOURCE = "capture_reports".freeze
  VERIFICATIONS = "capture_report_verifications".freeze

  def index?
    user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view", "#{VERIFICATIONS}.list",
                     "#{VERIFICATIONS}.view")
  end

  def show?   = user.permission?("#{RESOURCE}.view", "#{VERIFICATIONS}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def verify? = user.permission?("#{VERIFICATIONS}.verify")
  def request_amendment? = user.permission?("#{VERIFICATIONS}.amendment")
  def resubmit? = user.permission?("#{RESOURCE}.update")

  class Scope < Scope
    def resolve
      return scope if user.officer? || user.jetty_manager?

      scope.joins(:manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end
end
