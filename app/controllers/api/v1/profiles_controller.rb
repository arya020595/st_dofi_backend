module Api
  module V1
    class ProfilesController < ApplicationController
      def locale
        case Users::UpdateLocale.call(current_user, locale_param)
        in Success(user)
          render_locale_updated(user)
        in Failure(user)
          render_locale_invalid(user)
        end
      end

      private

      def locale_param
        params.expect(:locale)
      end

      def render_locale_updated(user)
        render json: {
          status: "success",
          message: "Language preference updated",
          data: { preferred_locale: user.preferred_locale }
        }, status: :ok
      end

      def render_locale_invalid(user)
        render json: {
          status: "fail",
          message: "Validation failed",
          data: { preferred_locale: user.errors[:preferred_locale] }
        }, status: :unprocessable_content
      end
    end
  end
end
