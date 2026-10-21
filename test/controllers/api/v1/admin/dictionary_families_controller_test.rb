require "test_helper"

module Api
  module V1
    module Admin
      class DictionaryFamiliesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          permissions = %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "dictionary_families.#{action}") do |permission|
              permission.name = permission.code
            end
          end
          role = create(:role, kind: Role::DOFI_OFFICER, permissions:)
          @user = create(:user, role:, position: "Administrator", unit: "HQ",
                                password: @password, password_confirmation: @password)
          @headers = auth_headers_for(@user, password: @password)
          @dictionary_family = create(:dictionary_family)
        end

        test "index returns dictionary families" do
          get "/api/v1/admin/dictionary_families", headers: @headers

          assert_response :ok
          assert_equal [@dictionary_family.id], response.parsed_body.fetch("data").pluck("id")
        end

        test "show returns the dictionary family" do
          get "/api/v1/admin/dictionary_families/#{@dictionary_family.id}", headers: @headers

          assert_response :ok
          assert_equal @dictionary_family.id, response.parsed_body.dig("data", "id")
        end

        test "create adds a dictionary family" do
          group = create(:dictionary_group)

          post "/api/v1/admin/dictionary_families",
               params: { dictionary_family: { name: "New Family", dictionary_group_id: group.id } }, headers: @headers

          assert_response :created
          assert_equal "New Family", response.parsed_body.dig("data", "name")
        end

        test "create returns errors for an invalid dictionary family" do
          post "/api/v1/admin/dictionary_families",
               params: { dictionary_family: { name: "", dictionary_group_id: @dictionary_family.dictionary_group_id } },
               headers: @headers

          assert_response :unprocessable_content
          assert_not_empty response.parsed_body.fetch("errors")
        end

        test "update changes the dictionary family name" do
          patch "/api/v1/admin/dictionary_families/#{@dictionary_family.id}",
                params: { dictionary_family: { name: "Updated Family" } }, headers: @headers

          assert_response :ok
          assert_equal "Updated Family", @dictionary_family.reload.name
        end

        test "destroy removes the dictionary family" do
          delete "/api/v1/admin/dictionary_families/#{@dictionary_family.id}", headers: @headers

          assert_response :ok
          assert_not DictionaryFamily.exists?(@dictionary_family.id)
        end
      end
    end
  end
end
