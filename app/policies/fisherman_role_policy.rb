class FishermanRolePolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record? && !record.system_managed_fisherman_role?

  def destroy?
    super && owns_record? && !record.is_default? && !record.is_default_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(platform_scope: Role::FISHERMAN_PLATFORM, company_profile_id: user.company_profile_id)
    end
  end

  private

  def permission_resource = "fisherman_roles"

  def owns_record?
    record.platform_scope == Role::FISHERMAN_PLATFORM && record.company_profile_id == user.company_profile_id
  end
end
