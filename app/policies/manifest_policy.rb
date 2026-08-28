class ManifestPolicy < ApplicationPolicy
  RESOURCE = "manifest".freeze
  LIST = "manifest_list".freeze
  FORM = "manifest_form".freeze
  APPROVALS = "manifest_approvals".freeze

  def index?
    return user.permission?("#{RESOURCE}.view") || fisherman_manifest_read? if fisherman_platform?

    user.permission?("#{LIST}.list", "#{APPROVALS}.list")
  end

  def tab_counts? = index?

  def show?
    return user.permission?("#{RESOURCE}.view") || fisherman_manifest_read? if fisherman_platform?

    user.permission?("#{LIST}.view", "#{FORM}.view", "#{APPROVALS}.view")
  end

  def create?
    return user.permission?("#{RESOURCE}.create") || fisherman_manifest_write? if fisherman_platform?

    user.permission?("#{FORM}.create")
  end

  def update? = user.permission?("#{LIST}.update")

  def fisherman_update?
    user.permission?("#{RESOURCE}.create") || fisherman_manifest_write?
  end

  def destroy?
    return user.permission?("#{RESOURCE}.delete") || fisherman_manifest_delete? if fisherman_platform?

    user.permission?("#{LIST}.delete")
  end

  def submit_port_out?
    return user.permission?("#{RESOURCE}.create") || fisherman_manifest_write? if fisherman_platform?

    user.permission?("#{FORM}.create")
  end

  def resubmit_port_out?
    return user.permission?("#{RESOURCE}.create") || fisherman_manifest_write? if fisherman_platform?

    user.permission?("#{FORM}.create")
  end

  def approve_port_out? = user.permission?("#{APPROVALS}.approve")
  def request_amendment_port_out? = user.permission?("#{APPROVALS}.amendment")

  def submit_port_in?
    return user.permission?("#{RESOURCE}.create") || fisherman_manifest_write? if fisherman_platform?

    user.permission?("#{FORM}.create")
  end

  def resubmit_port_in?
    return user.permission?("#{RESOURCE}.create") || fisherman_manifest_write? if fisherman_platform?

    user.permission?("#{FORM}.create")
  end

  def approve_port_in? = user.permission?("#{APPROVALS}.approve")
  def request_amendment_port_in? = user.permission?("#{APPROVALS}.amendment")

  def skip_capture_report?
    return user.permission?("#{RESOURCE}.create") || fisherman_manifest_write? if fisherman_platform?

    user.permission?("#{FORM}.create")
  end

  def offline_bundle? = show?

  class Scope < Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end
end
