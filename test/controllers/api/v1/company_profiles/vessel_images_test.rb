require "test_helper"

module Api
  module V1
    module CompanyProfiles
      class VesselImagesTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          permissions = %w[view list create update delete].map do |action|
            Permission.find_or_create_by!(code: "company_profiles.#{action}") { |p| p.name = "Vessels - #{action}" }
          end
          role = create(:role, kind: Role::DOFI_OFFICER, permissions:)
          admin = create(:user, :officer_shaped, role:, password: @password, password_confirmation: @password)
          @company_profile = create(:company_profile)
          @admin_headers = auth_headers_for(admin, password: @password)
        end

        test "show returns every image view as a key, nil when empty" do
          vessel = create(:companies_vessel, company_profile: @company_profile)
          vessel.front_image.attach(io: StringIO.new(png_bytes), filename: "boat.png", content_type: "image/png")

          get "/api/v1/admin/company_profiles/#{@company_profile.id}/vessels/#{vessel.id}", headers: @admin_headers

          assert_response :ok
          images = response.parsed_body.dig("data", "images")

          assert_equal %w[front back left right], images.keys
          assert_nil images["back"]
        end

        test "show returns an image as an authorized attachment path, never a storage URL" do
          vessel = create(:companies_vessel, company_profile: @company_profile)
          vessel.front_image.attach(io: StringIO.new(png_bytes), filename: "boat.png", content_type: "image/png")

          get "/api/v1/admin/company_profiles/#{@company_profile.id}/vessels/#{vessel.id}", headers: @admin_headers

          expected = { "url" => "/api/v1/attachments/#{vessel.front_image.blob.signed_id}", "filename" => "boat.png" }

          assert_equal expected, response.parsed_body.dig("data", "images", "front")
        end

        test "images upload fills only the given slots" do
          vessel = create(:companies_vessel, company_profile: @company_profile)

          post vessel_images_url(vessel), params: { images: { front: png_upload("a.png"), back: png_upload("b.png") } },
                                          headers: @admin_headers

          assert_response :ok
          assert_equal %w[a.png b.png], response.parsed_body.dig("data", "images").values.compact.pluck("filename")
        end

        test "images upload replaces a re-uploaded slot and keeps the others" do
          vessel = create(:companies_vessel, company_profile: @company_profile)
          vessel.front_image.attach(io: StringIO.new(png_bytes), filename: "a.png", content_type: "image/png")
          vessel.back_image.attach(io: StringIO.new(png_bytes), filename: "b.png", content_type: "image/png")

          post vessel_images_url(vessel), params: { images: { front: png_upload("c.png") } }, headers: @admin_headers

          images = response.parsed_body.dig("data", "images")

          assert_equal %w[c.png b.png], [images.dig("front", "filename"), images.dig("back", "filename")]
        end

        test "images upload rejects a non-image file" do
          vessel = create(:companies_vessel, company_profile: @company_profile)
          file = Rack::Test::UploadedFile.new(StringIO.new("hello"), "text/plain", original_filename: "a.txt")

          post vessel_images_url(vessel), params: { images: { front: file } }, headers: @admin_headers

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"], "Front image must be a JPEG or PNG"
        end

        test "destroy_image clears only the requested slot" do
          vessel = create(:companies_vessel, company_profile: @company_profile)
          vessel.front_image.attach(io: StringIO.new(png_bytes), filename: "boat.png", content_type: "image/png")
          vessel.back_image.attach(io: StringIO.new(png_bytes), filename: "back.png", content_type: "image/png")

          delete "#{vessel_images_url(vessel)}/front", headers: @admin_headers

          assert_response :ok
          images = response.parsed_body.dig("data", "images")

          assert_equal [nil, "back.png"], [images["front"], images.dig("back", "filename")]
        end

        test "destroy_image rejects an unknown view" do
          vessel = create(:companies_vessel, company_profile: @company_profile)

          delete "#{vessel_images_url(vessel)}/top", headers: @admin_headers

          assert_response :unprocessable_content
        end

        private

        def vessel_images_url(vessel)
          "/api/v1/admin/company_profiles/#{@company_profile.id}/vessels/#{vessel.id}/images"
        end

        def png_bytes
          Base64.decode64(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
          )
        end

        def png_upload(name)
          Rack::Test::UploadedFile.new(StringIO.new(png_bytes), "image/png", original_filename: name)
        end
      end
    end
  end
end
