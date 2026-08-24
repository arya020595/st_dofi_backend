require "test_helper"

module Api
  module V1
    # rubocop:disable Minitest/MultipleAssertions
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
        assert_nil response.parsed_body.dig("data", "next_action")
      end

      test "unknown jetty manager IC still returns registration action" do
        with_oidc_success("01-123456") do
          post "/api/v1/auth/brunei_id/callback",
               params: CALLBACK_PARAMS.merge(audience: "jetty_manager"), as: :json
        end

        assert_response :ok
        assert_equal "registration", response.parsed_body.dig("data", "next_action")
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

        assert_response :ok
        assert_equal "registration", response.parsed_body.dig("data", "next_action")
      end

      test "pending fisherman uses fisherman_status, not raw status" do
        company_profile = create(:company_profile)
        role = create(:role, :fisherman, company_profile: company_profile)
        create(:user, role: role, company_profile: company_profile, ic_number: "01-654321",
                      registration_type: "Commercial", status: "active", fisherman_status: "pending_approval")

        with_oidc_success("01654321") do
          post "/api/v1/auth/brunei_id/callback",
               params: CALLBACK_PARAMS.merge(audience: "fisherman"), as: :json
        end

        assert_response :ok
        assert_equal "registration_status", response.parsed_body.dig("data", "next_action")
        assert_equal "pending_approval", response.parsed_body.dig("data", "registration_status")
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
      end

      private

      def with_oidc_success(ic_number)
        singleton = BruneiId::OidcCallback.singleton_class
        original = BruneiId::OidcCallback.method(:call)
        result = Success(ic_number)
        singleton.define_method(:call) { |**_params| result }
        yield
      ensure
        singleton.define_method(:call) { |**params| original.call(**params) }
      end
    end
    # rubocop:enable Minitest/MultipleAssertions
  end
end
