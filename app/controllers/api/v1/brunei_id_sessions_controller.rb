module Api
  module V1
    # rubocop:disable Metrics/ClassLength
    class BruneiIdSessionsController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[create callback]
      skip_before_action :require_correct_audience, only: %i[create callback]

      def create
        case BruneiId::Client.call(ic_number: params.expect(:ic_number))
        in Success(verified_ic_number)
          render_for(User.kept.find_by(ic_number: verified_ic_number))
        in Failure(_reason)
          render json: { status: "fail", message: "Identity verification failed." }, status: :unauthorized
        end
      end

      def callback
        audience = callback_params[:audience]
        return render_invalid_audience unless supported_callback_audience?(audience)

        case BruneiId::OidcCallback.call(**callback_params.except(:audience).symbolize_keys)
        in Success(verified_ic_number)
          render_callback_for(user_for_callback_audience(verified_ic_number, audience), verified_ic_number:)
        in Failure(error)
          render_callback_error(error)
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

      def render_callback_for(user, verified_ic_number:)
        return render_callback_not_found(verified_ic_number) unless user
        return render_inactive_registration(user, verified_ic_number) if user.inactive? || user.suspended?

        return render_callback_dashboard(user, verified_ic_number) if user.active?

        render_callback_registration_status(user, verified_ic_number)
      end

      def render_callback_error(error)
        log_brunei_id_callback_result(
          next_action: nil,
          resolved_ic_number: nil,
          registration_status: nil,
          error_code: error[:code],
          error_message: error.fetch(:message)
        )
        render json: { status: "fail", message: error.fetch(:message), code: error[:code] },
               status: error.fetch(:status)
      end

      # rubocop:disable Metrics/MethodLength
      def render_callback_not_found(verified_ic_number)
        log_brunei_id_callback_result(
          next_action: "registration",
          resolved_ic_number: verified_ic_number,
          registration_status: "not_found"
        )
        render json: {
          status: "success",
          data: {
            next_action: "registration",
            ic_number: verified_ic_number,
            registration_status: "not_found"
          }
        }, status: :ok
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      def render_inactive_registration(user, verified_ic_number)
        log_brunei_id_callback_result(
          next_action: "registration_status",
          resolved_ic_number: verified_ic_number,
          registration_status: user.status,
          error_code: "inactive_registration",
          error_message: "Registration is not active."
        )
        render json: {
          status: "fail",
          message: "Registration is not active.",
          code: "inactive_registration",
          data: registration_status_payload(user, verified_ic_number)
        }, status: :unprocessable_content
      end
      # rubocop:enable Metrics/MethodLength

      def render_account_not_found
        render json: { status: "fail", message: I18n.t("errors.account_not_found") }, status: :not_found
      end

      def render_invalid_audience
        render json: {
          status: "fail",
          message: "Unsupported audience.",
          code: "unsupported_audience"
        }, status: :unprocessable_content
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

      def user_for_callback_audience(ic_number, audience)
        case audience
        when "fisherman"
          fisherman_user_for(ic_number)
        when "jetty_manager"
          jetty_manager_user_for(ic_number)
        end
      end

      def fisherman_user_for(ic_number)
        User.kept.joins(:role).find_by(ic_number: ic_number, roles: { platform_scope: Role::FISHERMAN_PLATFORM })
      end

      def jetty_manager_user_for(ic_number)
        User.kept.joins(:role).find_by(ic_number: ic_number, roles: { kind: Role::JETTY_MANAGER })
      end

      def render_callback_dashboard(user, verified_ic_number)
        sign_in(:user, user, store: false)
        log_brunei_id_callback_result(
          next_action: "dashboard",
          resolved_ic_number: verified_ic_number,
          registration_status: user.status
        )

        render json: {
          status: "success",
          data: dashboard_payload(user, verified_ic_number)
        }, status: :ok
      end

      def render_callback_registration_status(user, verified_ic_number)
        log_brunei_id_callback_result(
          next_action: "registration_status",
          resolved_ic_number: verified_ic_number,
          registration_status: user.status
        )
        render json: {
          status: "success",
          data: registration_status_payload(user, verified_ic_number)
        }, status: :ok
      end

      def dashboard_payload(user, verified_ic_number)
        registration_status_payload(user, verified_ic_number).merge(
          next_action: "dashboard",
          access_token: request.env["warden-jwt_auth.token"]
        )
      end

      def registration_status_payload(user, verified_ic_number)
        {
          next_action: "registration_status",
          user: UserBlueprint.render_as_hash(user),
          ic_number: verified_ic_number,
          registration_status: user.status
        }
      end

      # rubocop:disable Metrics/MethodLength
      def log_brunei_id_callback_result(next_action:, resolved_ic_number:, registration_status:,
                                        error_code: nil, error_message: nil)
        Rails.logger.info(
          {
            provider: "brunei_id",
            token_exchange_success: Current.brunei_id_token_response_keys.present?,
            token_response_keys: Current.brunei_id_token_response_keys || [],
            resolved_ic_number: ApiRequestLogs::Sanitizer.masked_ic_number(resolved_ic_number),
            next_action: next_action,
            registration_status: registration_status,
            error_code: error_code,
            error_message: error_message
          }.compact.to_json
        )
      end
      # rubocop:enable Metrics/MethodLength
    end
    # rubocop:enable Metrics/ClassLength
  end
end
