class ManifestMinorFishermanPolicy < ApplicationPolicy
  RESOURCE = "manifest_minor_fishermen".freeze

  def index?  = user.permission?("#{RESOURCE}.view")
  def show?   = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def destroy? = user.permission?("#{RESOURCE}.delete")

  class Scope < Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.where(manifest_id: Manifest.where(company_profile_id: user.company_profile_id).select(:id))
    end
  end
end
