require "test_helper"

module Api
  module V1
    # What the relay puts on the wire: the bytes, caching, and how risky types are served. Who may fetch a file is in
    # AttachmentsControllerTest.
    class AttachmentsRelayTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        @dictionary = create(:dictionary)
        @dictionary.image.attach(io: StringIO.new(png_bytes), filename: "fish.png", content_type: "image/png")
        @blob = @dictionary.image.blob
        @headers = auth_headers_for(user_with_permission("dictionaries.view"), password: @password)
      end

      test "sends the stored bytes with their content type" do
        get "/api/v1/attachments/#{@blob.signed_id}", headers: @headers

        assert_equal png_bytes, response.body.b
        assert_equal "image/png", response.media_type
      end

      test "is shown inline by default and as a download on request" do
        get "/api/v1/attachments/#{@blob.signed_id}", headers: @headers

        assert_match(/\Ainline/, response.headers["Content-Disposition"])

        get "/api/v1/attachments/#{@blob.signed_id}?disposition=attachment", headers: @headers

        assert_match(/\Aattachment/, response.headers["Content-Disposition"])
      end

      test "is private and revalidated on every request" do
        get "/api/v1/attachments/#{@blob.signed_id}", headers: @headers

        assert_equal %w[max-age=0 must-revalidate private], response.headers["Cache-Control"].split(", ").sort
        assert_predicate response.headers["ETag"], :present?
      end

      test "answers 304 without a body when the ETag still matches" do
        get "/api/v1/attachments/#{@blob.signed_id}", headers: @headers
        revisit = @headers.merge("If-None-Match" => response.headers["ETag"])

        get "/api/v1/attachments/#{@blob.signed_id}", headers: revisit

        assert_response :not_modified
        assert_empty response.body
      end

      test "still forbids a user without permission who sends a matching ETag" do
        get "/api/v1/attachments/#{@blob.signed_id}", headers: @headers
        denied = auth_headers_for(user_with_permission("dashboard.list"), password: @password)

        get "/api/v1/attachments/#{@blob.signed_id}", headers: denied.merge("If-None-Match" => response.headers["ETag"])

        assert_response :forbidden
      end

      test "serves a risky content type as an opaque download" do
        risky = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("<script>alert(1)</script>"),
                                                       filename: "x.html", content_type: "text/html")
        ActiveStorage::Attachment.create!(name: "image", record: @dictionary, blob: risky)

        get "/api/v1/attachments/#{risky.signed_id}", headers: @headers

        assert_equal "application/octet-stream", response.media_type
        assert_match(/\Aattachment/, response.headers["Content-Disposition"])
      end

      test "returns not found when the object is missing from storage" do
        @blob.service.delete(@blob.key)

        get "/api/v1/attachments/#{@blob.signed_id}", headers: @headers

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
