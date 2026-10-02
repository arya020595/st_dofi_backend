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
        headers = auth_headers_for(user_with_permission("dashboard.list"), password: @password)

        get "/api/v1/attachments/#{@signed_id}", headers: headers

        assert_response :forbidden
      end

      test "returns not found for a tampered or invalid signed_id" do
        headers = auth_headers_for(user_with_permission("dictionaries.view"), password: @password)

        get "/api/v1/attachments/not-a-real-signed-id", headers: headers

        assert_response :not_found
      end

      test "redirects an officer with company_profiles.view to a company vessel image" do
        image = vessel_image
        headers = auth_headers_for(user_with_permission("company_profiles.view"), password: @password)

        get "/api/v1/attachments/#{image.blob.signed_id}", headers: headers

        assert_response :found
      end

      test "redirects an officer with company_profiles.view to a company document file" do
        document = create(:companies_document)
        headers = auth_headers_for(user_with_permission("company_profiles.view"), password: @password)

        get "/api/v1/attachments/#{document.file.blob.signed_id}", headers: headers

        assert_response :found
      end

      test "lets a fisherman fetch their own company's vessel image but not another company's" do
        image = vessel_image
        own = fisherman_for(image.record.company_profile)
        other = fisherman_for(create(:company_profile))

        get "/api/v1/attachments/#{image.blob.signed_id}", headers: auth_headers_for(own, password: @password)

        assert_response :found

        get "/api/v1/attachments/#{image.blob.signed_id}", headers: auth_headers_for(other, password: @password)

        assert_response :forbidden
      end

      test "forbids a vessel image to a user without company_profiles.view" do
        image = vessel_image
        headers = auth_headers_for(user_with_permission("dictionaries.view"), password: @password)

        get "/api/v1/attachments/#{image.blob.signed_id}", headers: headers

        assert_response :forbidden
      end

      private

      def vessel_image
        vessel = create(:companies_vessel)
        vessel.images.attach(io: StringIO.new(png_bytes), filename: "boat.png", content_type: "image/png")
        vessel.images.first
      end

      def fisherman_for(company_profile)
        code = "company_profiles.view"
        permission = Permission.find_or_create_by!(code:) { |p| p.name = code }
        role = create(:role, :fisherman, company_profile:, permissions: [permission])
        create(:user, role:, company_profile:, registration_type: company_profile.registration_type,
                      ic_number: "73-#{SecureRandom.random_number(900_000) + 100_000}",
                      password: @password, password_confirmation: @password)
      end

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
