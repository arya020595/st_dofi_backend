module Api
  module V1
    class PasswordsController < ApplicationController
      skip_before_action :authenticate_user!

      def create
        Users::RequestPasswordReset.call(password_request_params[:email])

        render json: {
          status: "success",
          message: "If that email is registered, password reset instructions have been sent."
        }, status: :ok
      end

      def update
        case Users::ResetPassword.call(*password_reset_params.values_at(:token, :password, :password_confirmation))
        in Success(_user)
          render json: { status: "success", message: "Password has been reset." }, status: :ok
        in Failure(user)
          render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def password_request_params
        params.expect(user: [:email])
      end

      def password_reset_params
        params.expect(user: %i[token password password_confirmation])
      end
    end
  end
end
