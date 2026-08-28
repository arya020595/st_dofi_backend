class FishCaptureDetailPolicy < ApplicationPolicy
  RESOURCE = "capture_reports".freeze

  def index?
    fisherman_platform? ? fisherman_manifest_readable? : user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  end

  def show?
    fisherman_platform? ? fisherman_manifest_readable? : user.permission?("#{RESOURCE}.view")
  end

  def create?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.create")
  end

  def update?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.update")
  end

  def destroy?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.update")
  end

  def bulk_sync?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.create")
  end

  class Scope < Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(capture_report: :manifest).where(manifests: { company_profile_id: user.company_profile_id })
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
