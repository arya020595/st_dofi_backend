require "test_helper"

module Api
  module V1
    # Upload through the real endpoints, then read the same file back through the relay with the JWT. Guards the seam
    # between the two: browsers never reach storage, so what an upload returns must be fetchable via the API alone.
    class UploadRoundTripTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        codes = %w[dictionaries company_profiles company_documents].product(%w[view list create update delete])
                                                                   .map { |resource, action| "#{resource}.#{action}" }
        permissions = codes.map { |code| Permission.find_or_create_by!(code:) { |p| p.name = code } }
        role = create(:role, kind: Role::DOFI_OFFICER, permissions:)
        user = create(:user, :officer_shaped, role:, password: @password, password_confirmation: @password)
        @headers = auth_headers_for(user, password: @password)
      end

      test "a dictionary image uploaded on create is served back unchanged" do
        post "/api/v1/admin/dictionaries", params: { dictionary: dictionary_params(image: png_upload("fish.png")) },
                                           headers: @headers

        assert_response :created
        path = response.parsed_body.dig("data", 0, "image_url")

        assert_match(%r{\A/api/v1/attachments/}, path)
        assert_served path, png_bytes, "image/png"
      end

      test "a dictionary image is stored on the default service" do
        post "/api/v1/admin/dictionaries", params: { dictionary: dictionary_params(image: png_upload("fish.png")) },
                                           headers: @headers

        assert_equal Rails.application.config.active_storage.service.to_s, Dictionary.last.image.blob.service_name
      end

      test "replacing a dictionary image through update serves the new bytes" do
        dictionary = create(:dictionary)
        dictionary.image.attach(io: StringIO.new(png_bytes), filename: "old.png", content_type: "image/png")

        patch "/api/v1/admin/dictionaries/#{dictionary.id}", params: { dictionary: { image: jpeg_upload("new.jpg") } },
                                                             headers: @headers

        assert_response :ok
        assert_equal "new.jpg", dictionary.reload.image.filename.to_s
        assert_served response.parsed_body.dig("data", "image_url"), jpeg_bytes, "image/jpeg"
      end

      test "a spoofed dictionary image is rejected and leaves nothing behind" do
        html = Rack::Test::UploadedFile.new(StringIO.new("<!DOCTYPE html><script>alert(1)</script>"), "image/png",
                                            original_filename: "fake.png")

        assert_no_difference ["Dictionary.count", "ActiveStorage::Attachment.count"] do
          post "/api/v1/admin/dictionaries", params: { dictionary: dictionary_params(image: html) }, headers: @headers
        end

        assert_response :unprocessable_content
        assert_includes response.parsed_body["errors"].join, "must be a JPEG, PNG, or WebP"
      end

      test "a vessel image uploaded through the API is served back unchanged" do
        company = create(:company_profile)
        vessel = create(:companies_vessel, company_profile: company)

        post "/api/v1/admin/company_profiles/#{company.id}/vessels/#{vessel.id}/images",
             params: { images: { front: png_upload("boat.png") } }, headers: @headers

        assert_response :ok
        assert_served response.parsed_body.dig("data", "images", "front", "url"), png_bytes, "image/png"
      end

      test "a company document uploaded through the API is served back unchanged" do
        company = create(:company_profile)

        post "/api/v1/admin/company_profiles/#{company.id}/documents",
             params: { document: { document_type: "white_card",
                                   file: fixture_file_upload("sample.pdf", "application/pdf") } },
             headers: @headers

        assert_response :created
        assert_served response.parsed_body.dig("data", "document_url"), file_fixture("sample.pdf").binread,
                      "application/pdf"
      end

      private

      def assert_served(path, expected_bytes, expected_type)
        get path, headers: @headers

        assert_response :ok
        assert_equal expected_type, response.media_type
        assert_equal expected_bytes, response.body.b
      end

      def dictionary_params(extra)
        group = create(:dictionary_group)
        family = create(:dictionary_family, dictionary_group: group)
        { local_name: "Ikan Test", dictionary_group_id: group.id, dictionary_family_id: family.id }.merge(extra)
      end

      def png_upload(name)
        Rack::Test::UploadedFile.new(StringIO.new(png_bytes), "image/png", original_filename: name)
      end

      def jpeg_upload(name)
        Rack::Test::UploadedFile.new(StringIO.new(jpeg_bytes), "image/jpeg", original_filename: name)
      end

      # Minimal valid 1x1 transparent PNG.
      def png_bytes
        Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")
      end

      # Minimal valid 1x1 JPEG.
      def jpeg_bytes
        Base64.decode64(
          "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP////////////////////////////////////////////////////////////" \
          "////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="
        )
      end
    end
  end
end
