class CompaniesFishingGearPolicy < ApplicationPolicy
  RESOURCE = "companies_fishing_gears".freeze
  VESSEL_RESOURCE = "companies_vessels".freeze

  def index?
    return fisherman_vessel_access?(:list, :view) if fisherman_platform?

    user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  end

  def show?
    fisherman_platform? ? fisherman_vessel_access?(:view) : user.permission?("#{RESOURCE}.view")
  end

  def create?
    fisherman_platform? ? fisherman_vessel_access?(:create) : user.permission?("#{RESOURCE}.create")
  end

  def update?
    fisherman_platform? ? fisherman_vessel_access?(:update) : user.permission?("#{RESOURCE}.update")
  end

  def destroy?
    fisherman_platform? ? fisherman_vessel_access?(:delete) : user.permission?("#{RESOURCE}.delete")
  end

  class Scope < Scope
    def resolve
      return scope.kept if user.officer?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end

  private

  def fisherman_vessel_access?(*actions)
    legacy_codes = actions.map { |action| "#{RESOURCE}.#{action}" }
    vessel_codes = actions.map { |action| "#{VESSEL_RESOURCE}.#{action}" }
    user.permission?(*(legacy_codes + vessel_codes))
  end
end
