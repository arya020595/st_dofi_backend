require "test_helper"

module Api
  module V1
    class SessionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        @user = create(:user, password: @password, password_confirmation: @password)
      end

      test "sign in with valid credentials returns a JWT and the user payload" do
        post "/api/v1/auth/sign_in", params: { user: { email: @user.email, password: @password } }, as: :json

        assert_response :ok
        assert_predicate response.headers["Authorization"], :present?
        assert_equal @user.email, response.parsed_body.dig("data", "user", "email")
      end

      test "sign in response includes the access token alongside the Authorization header" do
        post "/api/v1/auth/sign_in", params: { user: { email: @user.email, password: @password } }, as: :json

        access_token = response.parsed_body.dig("data", "access_token")

        assert_predicate access_token, :present?
        assert_equal response.headers["Authorization"], "Bearer #{access_token}"
      end

      test "sign in with invalid credentials is rejected" do
        post "/api/v1/auth/sign_in", params: { user: { email: @user.email, password: "wrong-password" } }, as: :json

        assert_response :unauthorized
      end

      test "me requires authentication" do
        get "/api/v1/auth/me"

        assert_response :unauthorized
      end

      test "me returns the current user when authenticated" do
        get "/api/v1/auth/me", headers: auth_headers_for(@user, password: @password)

        assert_response :ok
        assert_equal @user.email, response.parsed_body.dig("data", "user", "email")
      end

      test "sign out revokes the token" do
        headers = auth_headers_for(@user, password: @password)

        delete "/api/v1/auth/sign_out", headers: headers

        assert_response :ok

        get "/api/v1/auth/me", headers: headers

        assert_response :unauthorized
      end
    end
  end
end
