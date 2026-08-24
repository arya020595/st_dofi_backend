class RolePolicy < ApplicationPolicy
  include PlatformScopedResource

  RESOURCE = "roles".freeze
  FISHERMAN_RESOURCE = "fisherman_roles".freeze

  def index?   = user.permission?("#{resource}.list", "#{resource}.view")
  def show?    = user.permission?("#{resource}.view") && owns_record?
  def create?  = user.permission?("#{resource}.create")
  def update?  = user.permission?("#{resource}.update") && owns_record? && modifiable_fisherman_role?

  def destroy?
    user.permission?("#{resource}.delete") && owns_record? && !record.is_default? && !record.is_default_admin?
  end

  class Scope < Scope
    def resolve
      return scope.where(platform_scope: Role::DOFI_OFFICER_PLATFORM) if user.dofi_officer_platform?
      return fisherman_scope if user.fisherman?

      scope.none
    end

    private

    def fisherman_scope
      scope.where(platform_scope: Role::FISHERMAN_PLATFORM, company_profile_id: user.company_profile_id)
    end
  end

  private

  # A DoFi Officer sees/manages every dofi_officer-platform role (unchanged from today's behavior).
  # A fisherman only ever owns their own company's fisherman-platform roles — this is the
  # record-level check RolePolicy never had before platform/company scoping existed.
  def owns_record?
    return true if user.dofi_officer_platform?

    record.platform_scope == Role::FISHERMAN_PLATFORM && record.company_profile_id == user.company_profile_id
  end

  def modifiable_fisherman_role?
    return true unless user.fisherman?

    !record.system_managed_fisherman_role?
  end
end
