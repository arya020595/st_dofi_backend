require "test_helper"

module Api
  module V1
    # Each case covers a distinct authentication response contract.
    # rubocop:disable Minitest/MultipleAssertions, Metrics/ClassLength
    class BruneiIdSessionsControllerTest < ActionDispatch::IntegrationTest
      include Dry::Monads[:result]

      CALLBACK_PARAMS = {
        code: "code",
        code_verifier: "verifier",
        redirect_uri: "https://example.test/callback",
        nonce: "nonce"
      }.freeze

      test "unknown fisherman IC stops without registration action" do
        with_oidc_success("01-123456") do
          assert_no_difference("User.count") do
            post "/api/v1/auth/brunei_id/callback",
                 params: CALLBACK_PARAMS.merge(audience: "fisherman"), as: :json
          end
        end

        assert_response :not_found
        assert_equal "fisherman_account_not_provisioned", response.parsed_body["code"]
        assert_equal "registration_status", response.parsed_body.dig("data", "next_action")
        assert_equal "not_found", response.parsed_body.dig("data", "registration_status")
        assert_equal "01-123456", response.parsed_body.dig("data", "ic_number")
      end

      test "unknown jetty manager IC stops as not provisioned" do
        with_oidc_success("01-123456") do
          assert_no_difference("User.count") do
            post "/api/v1/auth/brunei_id/callback",
                 params: CALLBACK_PARAMS.merge(audience: "jetty_manager"), as: :json
          end
        end

        assert_response :not_found
        assert_equal "jetty_manager_account_not_provisioned", response.parsed_body["code"]
        assert_equal "registration_status", response.parsed_body.dig("data", "next_action")
        assert_equal "not_found", response.parsed_body.dig("data", "registration_status")
        assert_equal "01-123456", response.parsed_body.dig("data", "ic_number")
      end

      test "jetty manager QR ignores fisherman account in audience-scoped lookup" do
        company_profile = create(:company_profile)
        role = create(:role, :fisherman, company_profile: company_profile)
        create(:user, role: role, company_profile: company_profile, ic_number: "01-223344",
                      registration_type: "Commercial", fisherman_status: "claimable")

        with_oidc_success("01223344") do
          post "/api/v1/auth/brunei_id/callback",
               params: CALLBACK_PARAMS.merge(audience: "jetty_manager"), as: :json
        end

        assert_response :not_found
        assert_equal "jetty_manager_account_not_provisioned", response.parsed_body["code"]
      end

      test "claimable fisherman claims then logs in" do
        company_profile = create(:company_profile)
        role = create(:role, :fisherman, company_profile: company_profile)
        user = create(:user, role: role, company_profile: company_profile, ic_number: "01-777123",
                             registration_type: "Commercial", fisherman_status: "claimable")

        with_oidc_success("01777123") do
          post "/api/v1/auth/brunei_id/callback",
               params: CALLBACK_PARAMS.merge(audience: "fisherman"), as: :json
        end

        assert_response :ok
        assert_equal "dashboard", response.parsed_body.dig("data", "next_action")
        assert_equal "active", user.reload.fisherman_status
        assert_dashboard_tokens(user)
      end

      test "active jetty manager callback returns dashboard tokens" do
        role = create(:role, kind: Role::JETTY_MANAGER)
        user = create(:user, :jetty_manager_shaped, role:)

        with_oidc_success(user.ic_number) { post_callback(audience: "jetty_manager") }

        assert_response :ok
        assert_equal "dashboard", response.parsed_body.dig("data", "next_action")
        assert_dashboard_tokens(user)
      end

      test "inactive jetty manager returns registration status without tokens" do
        role = create(:role, kind: Role::JETTY_MANAGER)
        user = create(:user, :jetty_manager_shaped, role:, status: "inactive")

        with_oidc_success(user.ic_number) { post_callback(audience: "jetty_manager") }

        assert_response :unprocessable_content
        assert_equal "inactive_registration", response.parsed_body["code"]
        assert_equal "inactive", response.parsed_body.dig("data", "registration_status")
        assert_nil response.parsed_body.dig("data", "access_token")
        assert_nil response.headers["Authorization"]
      end

      test "suspended and revoked fishermen cannot log in" do
        %w[suspended revoked].each do |status|
          user = create(:user, :fins_governed_fisherman, fisherman_status: status)
          with_oidc_success(user.ic_number) { post_callback }

          assert_response :unprocessable_content
          assert_equal "inactive_registration", response.parsed_body["code"]
          assert_equal status, response.parsed_body.dig("data", "registration_status")
          assert_nil response.headers["Authorization"]
        end
      end

      test "unsupported audience stops before verification" do
        with_brunei_id_result(-> { flunk "OIDC must not run for an unsupported audience" }) do
          post_callback(audience: "admin")
        end

        assert_response :unprocessable_content
        assert_equal({ "status" => "fail", "message" => "Unsupported audience.", "code" => "unsupported_audience" },
                     response.parsed_body)
      end

      test "missing callback parameters keep the bad request response" do
        post "/api/v1/auth/brunei_id/callback", params: { audience: "fisherman" }, as: :json

        assert_response :bad_request
        assert_equal "fail", response.parsed_body["status"]
      end

      test "an IC number alone cannot authenticate through the callback" do
        post "/api/v1/auth/brunei_id/callback", params: { audience: "fisherman", ic_number: "01-123456" }, as: :json

        assert_response :bad_request
        assert_nil response.headers["Authorization"]
      end

      test "the mock login route is absent when disabled" do
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("/api/v1/auth/brunei_id", method: :post)
        end
      end

      test "fisherman callback ignores a jetty manager account" do
        role = create(:role, kind: Role::JETTY_MANAGER)
        user = create(:user, :jetty_manager_shaped, role:)

        with_oidc_success(user.ic_number) { post_callback }

        assert_response :not_found
        assert_equal "fisherman_account_not_provisioned", response.parsed_body["code"]
        assert_nil response.headers["Authorization"]
      end

      test "request context is correlated and cleaned up after authentication failure" do
        observed_request_id = nil
        with_brunei_id_result(lambda {
          observed_request_id = Current.request_id
          Current.brunei_id_claims = { "name" => "Private Name" }
          Failure(BruneiId::OidcCallback::INVALID_CODE_ERROR)
        }) do
          post "/api/v1/auth/brunei_id/callback", params: CALLBACK_PARAMS.merge(audience: "fisherman"),
                                                  headers: { "X-Request-Id" => "callback-request-1" }, as: :json
        end

        assert_equal "callback-request-1", observed_request_id
        assert_empty Current.attributes.values.compact
      end

      test "an unexpected callback exception also clears request context" do
        with_brunei_id_result(lambda {
          Current.brunei_id_claims = { "name" => "Private Name" }
          raise "Unexpected provider failure"
        }) do
          assert_raises(RuntimeError) { post_callback }
        end

        assert_empty Current.attributes.values.compact
      end

      test "OIDC failures retain the original status code and message" do
        [BruneiId::OidcCallback::INVALID_CODE_ERROR, BruneiId::OidcCallback::TOKEN_VALIDATION_ERROR,
         BruneiId::OidcCallback::MISCONFIGURED_ERROR].each do |error|
          with_brunei_id_result(-> { Failure(error) }) { post_callback }

          assert_response error.fetch(:status)
          assert_equal({ "status" => "fail", "message" => error[:message], "code" => error[:code] },
                       response.parsed_body)
          assert_nil response.headers["Authorization"]
        end
      end

      test "profile and token metadata are preserved and cleared between requests" do
        with_brunei_id_result(lambda {
          Current.brunei_id_claims = { "name" => "Verified Name", "given_name" => "Verified", "sub" => "subject-1" }
          Current.brunei_id_userinfo = { "name" => "Other Name", "family_name" => "Family" }
          Current.brunei_id_token_metadata = { "token_type" => "Bearer", "expires_in" => 300, "scope" => "openid" }
          Current.brunei_id_token_response_keys = %w[id_token access_token token_type expires_in scope]
          Success("01-123456")
        }) { post_callback }

        data = response.parsed_body.fetch("data")

        assert_equal "Verified Name", data["full_name"]
        assert_equal({ "ic_number" => "01-123456", "full_name" => "Verified Name", "given_name" => "Verified",
                       "family_name" => "Family", "subject" => "subject-1" }, data["brunei_id_profile"])
        assert_equal({ "token_type" => "Bearer", "expires_in" => 300, "scope" => "openid",
                       "response_keys" => %w[id_token access_token token_type expires_in scope] },
                     data["brunei_id_token_metadata"])
        assert_nil Current.brunei_id_claims

        with_oidc_success("01-654321") { post_callback }

        assert_equal({ "ic_number" => "01-654321" }, response.parsed_body.dig("data", "brunei_id_profile"))
        assert_equal({ "response_keys" => [] }, response.parsed_body.dig("data", "brunei_id_token_metadata"))
        assert_not response.parsed_body.fetch("data").key?("full_name")
      end

      private

      def with_oidc_success(ic_number, &)
        with_brunei_id_result(-> { Success(ic_number) }, &)
      end

      def post_callback(audience: "fisherman")
        post "/api/v1/auth/brunei_id/callback", params: CALLBACK_PARAMS.merge(audience:), as: :json
      end

      def assert_dashboard_tokens(user)
        data = response.parsed_body.fetch("data")

        assert_equal response.headers["Authorization"], "Bearer #{data.fetch('access_token')}"
        payload, = JWT.decode(data.fetch("access_token"), nil, false)

        assert_equal user.id, payload.fetch("sub")
        assert_realtime_tokens(user, data)
      end

      def assert_realtime_tokens(user, data)
        assert_equal user, Realtime::CableToken.user_for(data.fetch("realtime_token"))
        assert_predicate Time.iso8601(data.fetch("realtime_token_expires_at")), :future?
      end
    end
    # rubocop:enable Minitest/MultipleAssertions, Metrics/ClassLength
  end
end
