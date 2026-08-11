class FishCaptureDetailPolicy < ApplicationPolicy
  RESOURCE = "capture_reports".freeze

  def index?  = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  def show?   = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def destroy? = user.permission?("#{RESOURCE}.update")
  def bulk_sync? = user.permission?("#{RESOURCE}.create")

  class Scope < Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(capture_report: :manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end
end
