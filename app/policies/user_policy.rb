class UserPolicy < ApplicationPolicy
  RESOURCE = "dofi_officer_users".freeze
  EXTERNAL_ROLE_REFERENCE_IDS = [User::JETTY_MANAGER_ROLE_REFERENCE_ID, User::FISHERMAN_ROLE_REFERENCE_ID].freeze

  def index? = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  def show? = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def destroy? = user.permission?("#{RESOURCE}.delete")

  class Scope < Scope
    def resolve
      scope.kept.where(role_id: nil).or(scope.kept.where.not(role_id: excluded_role_ids))
    end

    private

    def excluded_role_ids
      Role.where(reference_id: EXTERNAL_ROLE_REFERENCE_IDS).select(:id)
    end
  end
end
