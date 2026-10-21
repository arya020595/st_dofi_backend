module RequireAudience
  extend ActiveSupport::Concern

  # Namespace-level authorization boundary — a coarse pre-filter in front of Pundit's per-action/
  # per-record checks, not a replacement for them. config/routes.rb tags every route nested inside
  # `namespace :admin` / `namespace :fisherman` with `defaults: { audience: "admin"/"fisherman" }`;
  # this reads that routing-supplied value from params[:audience] — confirmed by hand that a
  # request-supplied query string of the same name cannot override it, since path_parameters take
  # precedence over query parameters in the merged params hash. Routes with no :audience default
  # (profile/locale, permissions, attachments) are a no-op here by design.
  #
  # Gates on Role#platform_scope (every role has one — dofi_officer or fisherman, see Role) rather
  # than checking "not fisherman?" — a future custom dofi_officer-platform role must land in the
  # admin audience by the same construction that already makes officer?/jetty_manager? land there,
  # not by exclusion.
  included do
    before_action :require_correct_audience
  end

  private

  def require_correct_audience
    case params[:audience]
    when "admin"
      render_forbidden unless current_user.dofi_officer_platform?
    when "fisherman"
      render_forbidden unless allowed_fisherman_audience?
    end
  end

  def allowed_fisherman_audience?
    return false unless current_user.fisherman?
    return current_user.current_fisherman_owner? if current_user.has_fisherman_owner_role?

    true
  end
end
