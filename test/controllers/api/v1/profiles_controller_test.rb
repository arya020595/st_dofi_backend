require "test_helper"

module Api
  module V1
    class ProfilesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        @user = create(:user, password: @password, password_confirmation: @password, preferred_locale: "en")
        @headers = auth_headers_for(@user, password: @password)
      end

      test "updates the user's preferred locale to ms" do
        patch "/api/v1/profile/locale", params: { locale: "ms" }, headers: @headers, as: :json

        assert_response :ok
        assert_equal "ms", response.parsed_body.dig("data", "preferred_locale")
        assert_equal "ms", @user.reload.preferred_locale
      end

      test "updates the user's preferred locale to en" do
        @user.update!(preferred_locale: "ms")

        patch "/api/v1/profile/locale", params: { locale: "en" }, headers: @headers, as: :json

        assert_response :ok
        assert_equal "en", response.parsed_body.dig("data", "preferred_locale")
        assert_equal "en", @user.reload.preferred_locale
      end

      test "rejects an invalid locale value" do
        patch "/api/v1/profile/locale", params: { locale: "zh" }, headers: @headers, as: :json

        assert_response :unprocessable_content
        assert_equal "fail", response.parsed_body["status"]
        assert_includes response.parsed_body.dig("data", "preferred_locale"), "is not included in the list"
      end

      test "does not persist an invalid locale value" do
        patch "/api/v1/profile/locale", params: { locale: "zh" }, headers: @headers, as: :json

        assert_equal "en", @user.reload.preferred_locale
      end

      test "translates the validation message according to the Accept-Language header" do
        patch "/api/v1/profile/locale",
              params: { locale: "zh" },
              headers: @headers.merge("Accept-Language" => "ms"),
              as: :json

        assert_response :unprocessable_content
        assert_includes response.parsed_body.dig("data", "preferred_locale"), "tidak termasuk dalam senarai"
      end

      test "requires authentication" do
        patch "/api/v1/profile/locale", params: { locale: "ms" }, as: :json

        assert_response :unauthorized
      end
    end
  end
end
