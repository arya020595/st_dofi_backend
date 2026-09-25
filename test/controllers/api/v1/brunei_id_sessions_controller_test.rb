require "test_helper"

module Api
  module V1
    class BruneiIdSessionsControllerTest < ActionDispatch::IntegrationTest
      include Dry::Monads[:result]

      CALLBACK_PARAMS = {
        code: "code",
        code_verifier: "verifier",
        redirect_uri: "https://example.test/callback",
        nonce: "nonce"
      }.freeze

      test "callback returns a token for an active fisherman" do
        fisherman = create_active_fisherman("01-777123")

        with_oidc_success(fisherman.ic_number) do
          post "/api/v1/auth/brunei_id/callback", params: CALLBACK_PARAMS.merge(audience: "fisherman"), as: :json
        end

        assert_response :ok
        assert_equal "dashboard", response.parsed_body.dig("data", "next_action")
        assert_predicate response.parsed_body.dig("data", "access_token"), :present?
      end

      test "callback returns unauthorized for an unknown or inactive account" do
        with_oidc_success("01-123456") do
          post "/api/v1/auth/brunei_id/callback", params: CALLBACK_PARAMS.merge(audience: "fisherman"), as: :json
        end

        assert_response :unauthorized
        assert_equal "Account is inactive or unavailable.", response.parsed_body.fetch("message")
      end

      private

      def create_active_fisherman(ic_number)
        company_profile = create(:company_profile)
        role = create(:role, :fisherman, company_profile: company_profile)
        create(:user, role:, company_profile:, ic_number:, registration_type: "Commercial",
                      fisherman_status: "active", claimed_at: Time.current, brunei_id_verified_at: Time.current)
      end

      def with_oidc_success(ic_number)
        singleton = BruneiId::OidcCallback.singleton_class
        original = BruneiId::OidcCallback.method(:call)
        singleton.define_method(:call) { |**_params| Success(ic_number) }
        yield
      ensure
        singleton.define_method(:call) { |**params| original.call(**params) }
      end
    end
  end
end
