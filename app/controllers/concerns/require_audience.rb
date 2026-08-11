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
      deny_wrong_audience("admin") unless current_user.dofi_officer_platform?
    when "fisherman"
      deny_wrong_audience("fisherman") unless current_user.fisherman?
    end
  end

  # Denial is logged deliberately: an ordinary grant here is just normal traffic already captured
  # by Lograge's per-request line, but a wrong-audience attempt is the same kind of signal worth
  # seeing on its own that Api::V1::AttachmentsController already logs for document access.
  def deny_wrong_audience(required_audience)
    platform_scope = current_user.role&.platform_scope || "none"
    Rails.logger.warn(
      "Audience access denied: user=#{current_user.id} role_platform_scope=#{platform_scope} " \
      "required_audience=#{required_audience} path=#{request.path}"
    )
    render_forbidden
  end
end
