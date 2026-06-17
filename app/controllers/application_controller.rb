class ApplicationController < ActionController::API
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

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
end
