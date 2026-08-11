class UserPolicy < ApplicationPolicy
  include PlatformScopedResource

  RESOURCE = "dofi_officer_users".freeze
  FISHERMAN_RESOURCE = "fisherman_users".freeze

  def index?   = user.permission?("#{resource}.list", "#{resource}.view")
  def show?    = user.permission?("#{resource}.view") && owns_record?
  def create?  = user.permission?("#{resource}.create")
  def update?  = user.permission?("#{resource}.update") && owns_record?
  def destroy? = user.permission?("#{resource}.delete") && owns_record?

  class Scope < Scope
    def resolve
      return admin_scope if user.dofi_officer_platform?
      return fisherman_scope if user.fisherman?

      scope.none
    end

    private

    # Excludes external (Jetty Manager / any fisherman-platform) users from the admin list — an
    # officer manages DoFi-Officer-platform accounts here, not any company's fisherman roster.
    def admin_scope
      scope.kept.where(role_id: nil).or(scope.kept.where.not(role_id: Role.external.select(:id)))
    end

    def fisherman_scope
      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end

  private

  def owns_record?
    return true if user.dofi_officer_platform?

    record.company_profile_id == user.company_profile_id
  end
end
