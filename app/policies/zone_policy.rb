class ZonePolicy < ApplicationPolicy
  RESOURCE = "zones".freeze

  def index?
    fisherman_platform? ? fisherman_lookup_access? : user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  end

  def show?
    fisherman_platform? ? fisherman_lookup_access? : user.permission?("#{RESOURCE}.view")
  end

  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def destroy? = user.permission?("#{RESOURCE}.delete")

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  def fisherman_lookup_access?
    user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view") || fisherman_manifest_read?
  end
end
