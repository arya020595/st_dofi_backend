class FishermanUserPolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record? && manageable_target?
  def destroy? = super && owns_record? && manageable_target?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept.where(company_profile_id: user.company_profile_id)
  end

  private

  def permission_resource = "fisherman_users"

  def owns_record? = record.company_profile_id == user.company_profile_id
  def manageable_target? = !record.has_fisherman_owner_role?
end
