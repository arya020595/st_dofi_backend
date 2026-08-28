class ManifestMinorFishermanPolicy < ApplicationPolicy
  RESOURCE = "manifest_minor_fishermen".freeze

  def index?
    fisherman_platform? ? fisherman_manifest_readable? : user.permission?("#{RESOURCE}.view")
  end

  def show?
    fisherman_platform? ? fisherman_manifest_readable? : user.permission?("#{RESOURCE}.view")
  end

  def create?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.create")
  end

  def destroy?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.delete")
  end

  class Scope < Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.where(manifest_id: Manifest.where(company_profile_id: user.company_profile_id).select(:id))
    end
  end

  private

  def fisherman_manifest_readable?
    user.permission?("#{RESOURCE}.view") || fisherman_manifest_read?
  end

  def fisherman_manifest_writeable?
    user.permission?("#{RESOURCE}.create", "#{RESOURCE}.delete") || fisherman_manifest_write?
  end
end
