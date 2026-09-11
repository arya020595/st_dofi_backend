class ManifestMinorFishermanPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.where(manifest_id: Manifest.where(company_profile_id: user.company_profile_id).select(:id))
    end
  end

  private

  def permission_resource = "manifest_minor_fishermen"
end
