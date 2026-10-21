require "test_helper"

module Api
  module V1
    module Admin
      class DictionaryGroupsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          permissions = %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "dictionary_groups.#{action}") do |permission|
              permission.name = permission.code
            end
          end
          role = create(:role, kind: Role::DOFI_OFFICER, permissions:)
          @user = create(:user, role:, position: "Administrator", unit: "HQ",
                                password: @password, password_confirmation: @password)
          @headers = auth_headers_for(@user, password: @password)
          @dictionary_group = create(:dictionary_group)
        end

        test "index returns dictionary groups" do
          get "/api/v1/admin/dictionary_groups", headers: @headers

          assert_response :ok
          assert_equal [@dictionary_group.id], response.parsed_body.fetch("data").pluck("id")
        end

        test "show returns the dictionary group" do
          get "/api/v1/admin/dictionary_groups/#{@dictionary_group.id}", headers: @headers

          assert_response :ok
          assert_equal @dictionary_group.id, response.parsed_body.dig("data", "id")
        end

        test "create adds a dictionary group" do
          post "/api/v1/admin/dictionary_groups", params: { dictionary_group: { name: "New Group" } }, headers: @headers

          assert_response :created
          assert_equal "New Group", response.parsed_body.dig("data", "name")
        end

        test "create returns errors for an invalid dictionary group" do
          post "/api/v1/admin/dictionary_groups", params: { dictionary_group: { name: "" } }, headers: @headers

          assert_response :unprocessable_content
          assert_not_empty response.parsed_body.fetch("errors")
        end

        test "update changes the dictionary group name" do
          patch "/api/v1/admin/dictionary_groups/#{@dictionary_group.id}",
                params: { dictionary_group: { name: "Updated Group" } }, headers: @headers

          assert_response :ok
          assert_equal "Updated Group", @dictionary_group.reload.name
        end

        test "destroy removes the dictionary group" do
          delete "/api/v1/admin/dictionary_groups/#{@dictionary_group.id}", headers: @headers

          assert_response :ok
          assert_not DictionaryGroup.exists?(@dictionary_group.id)
        end
      end
    end
  end
end
