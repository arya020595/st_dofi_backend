require "test_helper"

module Api
  module V1
    class PasswordsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = create(:user)
      end

      test "requesting a reset for a known email enqueues an email and returns success" do
        assert_enqueued_emails 1 do
          post "/api/v1/password", params: { user: { email: @user.email } }, as: :json
        end

        assert_response :ok
        assert_equal "success", response.parsed_body["status"]
      end

      test "requesting a reset for an unknown email still returns success without enqueuing an email" do
        assert_no_enqueued_emails do
          post "/api/v1/password", params: { user: { email: "nobody@example.com" } }, as: :json
        end

        assert_response :ok
        assert_equal "success", response.parsed_body["status"]
      end

      test "resetting with a valid token updates the password" do
        token = @user.send_reset_password_instructions

        patch "/api/v1/password", params: {
          user: { token: token, password: "NewPassword123!", password_confirmation: "NewPassword123!" }
        }, as: :json

        assert_response :ok
        assert @user.reload.valid_password?("NewPassword123!")
      end

      test "resetting with a mismatched confirmation fails" do
        token = @user.send_reset_password_instructions

        patch "/api/v1/password", params: {
          user: { token: token, password: "NewPassword123!", password_confirmation: "Different123!" }
        }, as: :json

        assert_response :unprocessable_content
      end

      test "resetting with an invalid token fails" do
        patch "/api/v1/password", params: {
          user: { token: "not-a-real-token", password: "NewPassword123!", password_confirmation: "NewPassword123!" }
        }, as: :json

        assert_response :unprocessable_content
      end

      test "resetting with an expired token fails" do
        token = @user.send_reset_password_instructions
        @user.update!(reset_password_sent_at: 7.hours.ago)

        patch "/api/v1/password", params: {
          user: { token: token, password: "NewPassword123!", password_confirmation: "NewPassword123!" }
        }, as: :json

        assert_response :unprocessable_content
      end
    end
  end
end
