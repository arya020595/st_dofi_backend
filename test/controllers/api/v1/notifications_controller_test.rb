require "test_helper"

module Api
  module V1
    class NotificationsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        @user = create(:user, password: @password, password_confirmation: @password)
        @headers = auth_headers_for(@user, password: @password)
      end

      test "index returns only the current user's notification history and unread count" do
        own_notification = create(:notification, user: @user)
        create(:notification)

        get "/api/v1/notifications", headers: @headers

        assert_response :ok
        assert_equal [own_notification.id], response.parsed_body.fetch("data").pluck("id")
        assert_equal 1, response.parsed_body.dig("meta", "unread_count")
      end

      test "read marks only the current user's notification as read" do
        notification = create(:notification, user: @user)

        patch "/api/v1/notifications/#{notification.id}/read", headers: @headers, as: :json

        assert_response :ok
        assert_predicate notification.reload, :read_at?
        assert_equal 0, response.parsed_body.dig("meta", "unread_count")
      end
    end
  end
end
