require "test_helper"

module Api
  module V1
    module Registrations
      class StatusControllerTest < ActionDispatch::IntegrationTest
        setup do
          @role = create(:role)
        end

        test "show returns the user record when ic_number is found" do
          user = create(:user, role: @role, ic_number: "01-123456")

          get "/api/v1/registrations/status", params: { ic_number: "01-123456" }

          assert_response :ok
          assert_equal user.id, response.parsed_body.dig("data", "id")
        end

        test "show exposes the user status so FE can branch on pending, rejected, or active" do
          create(:role, reference_id: "ROLE-003", name: "Fisherman")
          post "/api/v1/registrations/fisherman",
               params: { user: { name: "Solo", ic_number: "01-999999",
                                 registration_type: "Small - Scale (Full-Time)" } }, as: :json

          get "/api/v1/registrations/status", params: { ic_number: "01-999999" }

          assert_response :ok
          assert_equal "pending", response.parsed_body.dig("data", "status")
        end

        test "show returns not found when no user has the given ic_number" do
          get "/api/v1/registrations/status", params: { ic_number: "00-000000" }

          assert_response :not_found
        end

        test "show does not require authentication" do
          create(:user, role: @role, ic_number: "01-111111")

          get "/api/v1/registrations/status", params: { ic_number: "01-111111" }

          assert_response :ok
        end
      end
    end
  end
end
