module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json

      skip_before_action :authenticate_user!, only: %i[new create]
      skip_before_action :verify_signed_out_user, only: :destroy

      # authenticate_user! is a no-op inside any Devise-derived controller unless forced
      # (Devise assumes its own controllers manage authentication themselves).
      before_action(only: %i[me destroy]) { authenticate_user!(force: true) }

      def new
        head :not_found
      end

      def create
        self.resource = warden.authenticate!(auth_options)
        sign_in(resource_name, resource)
        render json: { status: "success", data: { user: UserBlueprint.render_as_hash(resource) } }, status: :ok
      end

      def destroy
        sign_out(current_user)
        render json: { status: "success", message: "Signed out successfully." }, status: :ok
      end

      def me
        render json: { status: "success", data: { user: UserBlueprint.render_as_hash(current_user) } }, status: :ok
      end
    end
  end
end
