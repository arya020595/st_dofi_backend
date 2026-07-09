require "test_helper"

module Api
  module V1
    class BruneiIdSessionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @role = create(:role)
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
    end
  end
end
