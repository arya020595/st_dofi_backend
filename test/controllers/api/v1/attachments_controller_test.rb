require "test_helper"

module Api
  module V1
    class AttachmentsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        @dictionary = create(:dictionary)
        @dictionary.image.attach(io: StringIO.new(png_bytes), filename: "fish.png", content_type: "image/png")
        @signed_id = @dictionary.image.blob.signed_id
      end

      test "requires authentication" do
        get "/api/v1/attachments/#{@signed_id}"

        assert_response :unauthorized
      end

      test "redirects to a freshly signed storage URL when the user is authorized" do
        headers = auth_headers_for(user_with_permission("dictionaries.view"), password: @password)

        get "/api/v1/attachments/#{@signed_id}", headers: headers

        assert_response :found
        assert_predicate response.headers["Location"], :present?
        assert_equal %w[max-age=0 private], response.headers["Cache-Control"].split(", ").sort
      end

      test "forbids a user without permission on the owning record" do
        headers = auth_headers_for(user_with_permission("dashboard.view"), password: @password)

        get "/api/v1/attachments/#{@signed_id}", headers: headers

        assert_response :forbidden
      end

      test "returns not found for a tampered or invalid signed_id" do
        headers = auth_headers_for(user_with_permission("dictionaries.view"), password: @password)

        get "/api/v1/attachments/not-a-real-signed-id", headers: headers

        assert_response :not_found
      end

      private

      def user_with_permission(code)
        permission = Permission.find_or_create_by!(code:) { |p| p.name = code }
        role = create(:role, permissions: [permission])
        create(:user, role:, password: @password, password_confirmation: @password)
      end

      # Minimal valid 1x1 transparent PNG.
      def png_bytes
        Base64.decode64(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        )
      end
    end
  end
end
