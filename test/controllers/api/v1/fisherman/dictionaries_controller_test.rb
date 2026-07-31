require "test_helper"

module Api
  module V1
    module Fisherman
      class DictionariesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          permissions = %w[manifest_form.create].map do |code|
            Permission.find_or_create_by!(code: code) { |permission| permission.name = code }
          end
          @role = create(:role, kind: Role::FISHERMAN, permissions: permissions)
          @user = create(:user, role: @role, ic_number: "01-800200", registration_type: "Commercial",
                                password: @password, password_confirmation: @password)
          @headers = auth_headers_for(@user, password: @password)
        end

        test "index requires manifest create permission" do
          plain_user = create(:user, password: @password, password_confirmation: @password)

          get "/api/v1/fisherman/dictionaries", headers: auth_headers_for(plain_user, password: @password)

          assert_response :forbidden
        end

        test "index returns dictionaries ordered by local_name" do
          create(:dictionary, local_name: "Ikan Tuna")
          create(:dictionary, local_name: "Ikan Bilis")

          get "/api/v1/fisherman/dictionaries", headers: @headers

          assert_response :ok
          assert_equal ["Ikan Bilis", "Ikan Tuna"], response.parsed_body["data"].pluck("local_name")
        end
      end
    end
  end
end
