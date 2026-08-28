class CaptureReportPolicy < ApplicationPolicy
  RESOURCE = "capture_reports".freeze
  VERIFICATIONS = "capture_report_verifications".freeze

  def index?
    return fisherman_manifest_readable? if fisherman_platform?

    user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view", "#{VERIFICATIONS}.list",
                     "#{VERIFICATIONS}.view")
  end

  def show?
    fisherman_platform? ? fisherman_manifest_readable? : user.permission?("#{RESOURCE}.view", "#{VERIFICATIONS}.view")
  end

  def create?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.create")
  end

  def update?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.update")
  end

  def verify? = user.permission?("#{VERIFICATIONS}.verify")
  def request_amendment? = user.permission?("#{VERIFICATIONS}.amendment")

  def resubmit?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.update")
  end

  class Scope < Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(:manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end

  private

  def fisherman_manifest_readable?
    user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view") || fisherman_manifest_read?
  end

  def fisherman_manifest_writeable?
    user.permission?("#{RESOURCE}.create", "#{RESOURCE}.update") || fisherman_manifest_write?
  end
end
