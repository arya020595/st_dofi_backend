module Api
  module V1
    class BruneiIdSessionsController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[create callback]
      skip_before_action :require_correct_audience, only: %i[create callback]

      def create
        case BruneiIdSessions::MockAuthenticate.call(ic_number: params.expect(:ic_number), audience: params[:audience])
        in Success(session)
          render json: BruneiIdSessionBlueprint.render_as_hash(session, **sign_in_and_issue_tokens(session)),
                 status: :ok
        in Failure(error)
          render json: BruneiIdSessionBlueprint.render_as_hash(error), status: error.fetch(:status)
        end
      end

      def callback
        case BruneiIdSessions::Authenticate.call(**callback_params)
        in Success(session)
          render json: BruneiIdSessionBlueprint.render_as_hash(session, **sign_in_and_issue_tokens(session)),
                 status: :ok
        in Failure(error)
          render json: BruneiIdSessionBlueprint.render_as_hash(error), status: error.fetch(:status)
        end
      end

      private

      def sign_in_and_issue_tokens(session)
        return {} unless %i[dashboard mock_dashboard].include?(session.fetch(:kind))

        user = session.fetch(:user)
        sign_in(:user, user, store: false)
        { access_token: request.env["warden-jwt_auth.token"], realtime_tokens: Realtime::CableToken.issue(user) }
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
    end
  end
end
