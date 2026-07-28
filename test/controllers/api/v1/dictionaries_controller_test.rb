require "test_helper"

module Api
  module V1
    class DictionariesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        permission = Permission.find_or_create_by!(code: "dictionaries.view") { |p| p.name = "Dictionaries - View" }
        role = create(:role, permissions: [permission])
        @user = create(:user, role:, password: @password, password_confirmation: @password)
        @headers = auth_headers_for(@user, password: @password)
      end

      test "image_url is a direct public-bucket URL, not the private redirect endpoint" do
        dictionary = create(:dictionary)
        dictionary.image.attach(io: StringIO.new("fake image bytes"), filename: "fish.png", content_type: "image/png")

        get "/api/v1/dictionaries/#{dictionary.id}", headers: @headers

        assert_response :ok
        image_url = response.parsed_body["data"]["image_url"]

        assert_predicate image_url, :present?
        assert_not_includes image_url, "/api/v1/attachments/"
      end

      test "image_url is nil when no image is attached" do
        dictionary = create(:dictionary)

        get "/api/v1/dictionaries/#{dictionary.id}", headers: @headers

        assert_response :ok
        assert_nil response.parsed_body["data"]["image_url"]
      end
    end
  end
end
