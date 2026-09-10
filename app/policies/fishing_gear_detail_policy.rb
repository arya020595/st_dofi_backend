class FishingGearDetailPolicy < ApplicationPolicy
  RESOURCE = "fishing_gear_details".freeze

  def index? = user.permission?("#{RESOURCE}.list")
  def show? = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def destroy? = user.permission?("#{RESOURCE}.delete")

  class Scope < Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(capture_report: :manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end
end
