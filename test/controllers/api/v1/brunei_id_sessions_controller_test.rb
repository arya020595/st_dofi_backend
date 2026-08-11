require "test_helper"

module Api
  module V1
    # rubocop:disable Metrics/ClassLength
    class BruneiIdSessionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @role = create(:role)
        @fisherman_role = Role.find_or_create_by!(kind: Role::FISHERMAN) do |role|
          role.name = "Fisherman"
          role.description = "Fisherman role"
        end
      end

      test "create signs in and returns a token when the user is active" do
        create(:user, role: @role, ic_number: "01-800101", status: "active")

        post "/api/v1/auth/brunei_id", params: { ic_number: "01-800101" }

        assert_response :ok
        assert_predicate response.headers["Authorization"], :present?
        assert_predicate response.parsed_body.dig("data", "access_token"), :present?
      end

      test "create returns status only, without a token, when the user is pending" do
        create(:user, role: @role, ic_number: "01-800102", status: "pending")

        post "/api/v1/auth/brunei_id", params: { ic_number: "01-800102" }

        assert_response :ok
        assert_equal "pending", response.parsed_body.dig("data", "status")
        assert_nil response.parsed_body.dig("data", "access_token")
      end

      test "create returns the rejection reason when the user was rejected" do
        create(:user, role: @role, ic_number: "01-800103", status: "rejected",
                      rejection_reason: "Information mismatch")

        post "/api/v1/auth/brunei_id", params: { ic_number: "01-800103" }

        assert_response :ok
        assert_equal "rejected", response.parsed_body.dig("data", "status")
        assert_equal "Information mismatch", response.parsed_body.dig("data", "rejection_reason")
      end

      test "create returns not found when no user has the given ic_number" do
        post "/api/v1/auth/brunei_id", params: { ic_number: "00-000000" }

        assert_response :not_found
        assert_equal "Account not found.", response.parsed_body["message"]
      end

      test "create does not require authentication" do
        create(:user, role: @role, ic_number: "01-800104", status: "active")

        post "/api/v1/auth/brunei_id", params: { ic_number: "01-800104" }

        assert_response :ok
      end

      test "create rejects a blank ic_number" do
        post "/api/v1/auth/brunei_id", params: { ic_number: "" }

        # params.expect(:ic_number) itself 400s on a blank value (same as every other endpoint's
        # ic_number param in this app), before BruneiId::Client's own blank-check ever runs.
        assert_response :bad_request
      end

      # rubocop:disable Minitest/MultipleAssertions
      test "callback returns fisherman access token when the resolved user is active" do
        create(:user, role: @fisherman_role, ic_number: "01-700101", status: "active",
                      registration_type: "Commercial")
        result = Dry::Monads::Result::Success.new("01-700101")

        stub_singleton_method(BruneiId::OidcCallback, :call, result) do
          post "/api/v1/auth/brunei_id/callback",
               params: callback_params, as: :json
        end

        assert_response :ok
        assert_equal "dashboard", response.parsed_body.dig("data", "next_action")
        assert_equal "active", response.parsed_body.dig("data", "registration_status")
        assert_predicate response.parsed_body.dig("data", "access_token"), :present?
      end
      # rubocop:enable Minitest/MultipleAssertions

      # rubocop:disable Minitest/MultipleAssertions
      test "callback returns registration_status when fisherman is still pending" do
        create(:user, role: @fisherman_role, ic_number: "01-700102", status: "pending",
                      registration_type: "Commercial")
        result = Dry::Monads::Result::Success.new("01-700102")

        stub_singleton_method(BruneiId::OidcCallback, :call, result) do
          post "/api/v1/auth/brunei_id/callback",
               params: callback_params, as: :json
        end

        assert_response :ok
        assert_equal "registration_status", response.parsed_body.dig("data", "next_action")
        assert_equal "pending", response.parsed_body.dig("data", "registration_status")
        assert_nil response.parsed_body.dig("data", "access_token")
      end
      # rubocop:enable Minitest/MultipleAssertions

      test "callback returns registration when fisherman record is not found" do
        result = Dry::Monads::Result::Success.new("01-700103")

        stub_singleton_method(BruneiId::OidcCallback, :call, result) do
          post "/api/v1/auth/brunei_id/callback",
               params: callback_params, as: :json
        end

        assert_response :ok
        assert_equal "registration", response.parsed_body.dig("data", "next_action")
        assert_equal "not_found", response.parsed_body.dig("data", "registration_status")
      end

      test "callback rejects unsupported audience" do
        post "/api/v1/auth/brunei_id/callback",
             params: callback_params.merge(audience: "admin"), as: :json

        assert_response :unprocessable_content
        assert_equal "unsupported_audience", response.parsed_body["code"]
      end

      test "callback returns clear oidc errors" do
        result = Dry::Monads::Result::Failure.new(
          {
            status: :unauthorized,
            code: "token_validation_failed",
            message: "ID token validation failed."
          }
        )

        stub_singleton_method(BruneiId::OidcCallback, :call, result) do
          post "/api/v1/auth/brunei_id/callback",
               params: callback_params, as: :json
        end

        assert_response :unauthorized
        assert_equal "token_validation_failed", response.parsed_body["code"]
      end

      private

      def stub_singleton_method(target, method_name, return_value)
        singleton = target.singleton_class
        original_defined = singleton.method_defined?(method_name) || singleton.private_method_defined?(method_name)
        original_method = singleton.instance_method(method_name) if original_defined

        singleton.send(:define_method, method_name) { |*| return_value }
        yield
      ensure
        singleton.send(:remove_method, method_name)
        singleton.send(:define_method, method_name, original_method) if original_defined
      end

      def callback_params
        {
          code: "opaque-auth-code",
          code_verifier: "pkce-verifier",
          redirect_uri: "http://217.217.252.45:4100/general/auth/brunei-id/callback",
          nonce: "nonce-value",
          audience: "fisherman"
        }
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
