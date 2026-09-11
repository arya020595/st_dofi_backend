class RolePolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record?

  def destroy?
    super && owns_record? && !record.is_default? && !record.is_default_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(platform_scope: Role::DOFI_OFFICER_PLATFORM)
    end
  end

  private

  def permission_resource = "roles"

  def owns_record? = record.platform_scope == Role::DOFI_OFFICER_PLATFORM
end
