class AdminAccountPolicy < ApplicationPolicy
  FISHERMAN_CATEGORY = "fisherman_account".freeze
  JETTY_MANAGER_CATEGORY = "jetty_manager_account".freeze

  def index? = fisherman_permission?(:list, :view) || jetty_manager_permission?(:list, :view)
  def show? = readable_account?
  def deactivate? = manageable_account?(:deactivate)
  def reactivate? = manageable_account?(:reactivate)

  class Scope < Scope
    def resolve
      relations = []
      relations << fisherman_accounts if fisherman_permission?(:list, :view)
      relations << jetty_manager_accounts if jetty_manager_permission?(:list, :view)
      return scope.none if relations.empty?

      relations.reduce { |combined, relation| combined.or(relation) }
    end

    private

    def fisherman_accounts
      scope.kept.joins(:role)
           .where(provisioning_source: ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE)
           .where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
           .where("roles.is_default = TRUE OR roles.is_default_admin = TRUE")
    end

    def jetty_manager_accounts
      scope.kept.joins(:role).where(roles: { kind: Role::JETTY_MANAGER })
    end

    def fisherman_permission?(*actions)
      user.permission?(*actions.map { |action| "fisherman_approvals.#{action}" })
    end

    def jetty_manager_permission?(*actions)
      user.permission?(*actions.map { |action| "jetty_manager_approvals.#{action}" })
    end
  end

  private

  def readable_account?
    fisherman_account? ? fisherman_permission?(:view) : jetty_manager_permission?(:view)
  end

  def manageable_account?(action)
    return fisherman_permission?(action) && record.fins_governed_fisherman? if fisherman_account?

    jetty_manager_permission?(action) && record.fins_governed_jetty_manager?
  end

  def fisherman_account? = record.fisherman?

  def fisherman_permission?(*actions)
    user.permission?(*actions.map { |action| "fisherman_approvals.#{action}" })
  end

  def jetty_manager_permission?(*actions)
    user.permission?(*actions.map { |action| "jetty_manager_approvals.#{action}" })
  end
end
