class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Pagy::Method
  include Dry::Monads[:result]

  before_action :authenticate_user!
  before_action :set_locale

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ActiveStorage::IntegrityError, CloudinaryException, with: :render_storage_error

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

  def render_forbidden
    render json: { status: "fail", message: "You are not authorized to perform this action." }, status: :forbidden
  end

  def render_not_found
    render json: { status: "fail", message: "Resource not found." }, status: :not_found
  end

  def render_bad_request(exception)
    render json: { status: "fail", message: exception.message }, status: :bad_request
  end

  def render_storage_error(exception)
    render json: { status: "fail", message: "Image upload failed: #{exception.message}" },
           status: :unprocessable_content
  end

  def pagination_meta(pagy)
    { page: pagy.page, pages: pagy.last, count: pagy.count, limit: pagy.limit }
  end
end
