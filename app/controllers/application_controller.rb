class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Pagy::Method
  include Dry::Monads[:result]
  # Sets ActiveStorage::Current.url_options from the current request — required by the Disk
  # service (test/development) whenever a blueprint calls blob.service.url directly; a no-op for
  # the S3 service (MinIO in staging/production), which never touches Rails' router.
  include ActiveStorage::SetCurrent

  before_action :authenticate_user!
  before_action :set_locale

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ActiveStorage::IntegrityError, CloudinaryException, Aws::Errors::ServiceError,
              Seahorse::Client::NetworkingError, with: :render_storage_error

  private

  # Locale is never sent in the JSON body (see docs/locale) — only via the Accept-Language
  # header, which the FE sets globally after login/preference update.
  def set_locale
    I18n.locale = User::VALID_LOCALES.include?(request_locale) ? request_locale : I18n.default_locale
  end

  def request_locale
    request.headers["Accept-Language"]
  end

  def append_info_to_payload(payload)
    super
    payload[:request_id] = request.request_id
    payload[:user_id] = current_user&.id
  end

  def render_error(message, status)
    render json: {
      status: "fail",
      message:
    }, status:
  end

  def render_forbidden
    render_error(I18n.t("errors.forbidden"), :forbidden)
  end

  def render_not_found
    render_error(I18n.t("errors.not_found"), :not_found)
  end

  def render_bad_request(exception)
    render_error(exception.message, :bad_request)
  end

  def render_storage_error(exception)
    Rails.logger.error(exception.full_message)
    render_error(I18n.t("errors.storage_failed"), :unprocessable_content)
  end

  def pagination_meta(pagy)
    { page: pagy.page, pages: pagy.last, count: pagy.count, limit: pagy.limit }
  end
end
