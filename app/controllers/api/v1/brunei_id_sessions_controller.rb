module Api
  module V1
    class BruneiIdSessionsController < ApplicationController
      skip_before_action :authenticate_user!, only: :create

      def create
        case BruneiId::Client.call(ic_number: params.expect(:ic_number))
        in Success(verified_ic_number)
          render_for(User.kept.find_by(ic_number: verified_ic_number))
        in Failure(_reason)
          render json: { status: "fail", message: "Identity verification failed." }, status: :unauthorized
        end
      end

      private

      def render_for(user)
        return render_account_not_found unless user
        return render_status_only(user) unless user.active?

        sign_in(:user, user, store: false)
        render json: { status: "success",
                       data: { access_token: request.env["warden-jwt_auth.token"],
                               user: UserBlueprint.render_as_hash(user) } }, status: :ok
      end

      def render_status_only(user)
        render json: { status: "success", data: UserBlueprint.render_as_hash(user) }, status: :ok
      end

      def render_account_not_found
        render json: { status: "fail", message: I18n.t("errors.account_not_found") }, status: :not_found
      end
    end
  end
end
