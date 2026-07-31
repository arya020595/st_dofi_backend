require "test_helper"

module Api
  module V1
    module Fisherman
      class ZonesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          permissions = %w[manifest_form.create].map do |code|
            Permission.find_or_create_by!(code: code) { |permission| permission.name = code }
          end
          @role = create(:role, permissions: permissions)
          @user = create(:user, role: @role, password: @password, password_confirmation: @password)
          @headers = auth_headers_for(@user, password: @password)
        end

        test "index requires manifest create permission" do
          plain_user = create(:user, password: @password, password_confirmation: @password)

          get "/api/v1/fisherman/zones", headers: auth_headers_for(plain_user, password: @password)

          assert_response :forbidden
        end

        test "index returns zones ordered by name" do
          create(:zone, name: "Zone 3")
          create(:zone, name: "Zone 1A")

          get "/api/v1/fisherman/zones", headers: @headers

          assert_response :ok
          assert_equal ["Zone 1A", "Zone 3"], response.parsed_body["data"].pluck("name")
        end
      end
    end
  end
end
