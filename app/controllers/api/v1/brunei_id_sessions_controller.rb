module Api
  module V1
    class BruneiIdSessionsController < ApplicationController
      include BruneiIdSessions::CallbackRendering
      include BruneiIdSessions::LegacyRendering
      include BruneiIdSessions::ProfilePayload
      include BruneiIdSessions::ResponsePayloads
      include BruneiIdSessions::ResponseRendering
      include BruneiIdSessions::ResultLogging

      skip_before_action :authenticate_user!, only: %i[create callback]
      skip_before_action :require_correct_audience, only: %i[create callback]

      def create
        case BruneiId::Client.call(ic_number: params.expect(:ic_number))
        in Success(verified_ic_number)
          render_for(user_for_verified_ic(verified_ic_number), verified_ic_number: verified_ic_number)
        in Failure(_reason)
          render json: { status: "fail", message: "Identity verification failed." }, status: :unauthorized
        end
      end

      def callback
        audience = callback_params[:audience]
        return render_invalid_audience unless supported_callback_audience?(audience)

        case BruneiId::OidcCallback.call(**callback_params.except(:audience).symbolize_keys)
        in Success(verified_ic_number)
          render_callback_success(verified_ic_number, audience)
        in Failure(error)
          render_callback_error(error)
        end
      end

      private

      def render_callback_success(verified_ic_number, audience)
        return render_fisherman_callback(verified_ic_number) if audience == "fisherman"

        render_callback_for(jetty_manager_user_for(verified_ic_number), verified_ic_number:, audience:)
      end

      def callback_params
        {
          code: params.expect(:code),
          code_verifier: params.expect(:code_verifier),
          redirect_uri: params.expect(:redirect_uri),
          nonce: params.expect(:nonce),
          audience: params.expect(:audience)
        }
      end

      def supported_callback_audience?(audience)
        %w[fisherman jetty_manager].include?(audience)
      end

      def user_for_verified_ic(ic_number)
        User.kept.find_by(normalized_ic_number: IcNumbers::Normalize.call(ic_number))
      end

      def jetty_manager_user_for(ic_number)
        User.kept.joins(:role).find_by(
          normalized_ic_number: IcNumbers::Normalize.call(ic_number),
          roles: { kind: Role::JETTY_MANAGER }
        )
      end
    end
  end
end
