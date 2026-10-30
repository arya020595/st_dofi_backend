require "test_helper"

module Api
  module V1
    module Admin
      class DictionariesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          permission = Permission.find_or_create_by!(code: "dictionaries.view") { |p| p.name = "Dictionaries - View" }
          role = create(:role, kind: Role::DOFI_OFFICER, permissions: [permission])
          @user = create(:user, role:, position: "Administrator", unit: "HQ",
                                password: @password, password_confirmation: @password)
          @headers = auth_headers_for(@user, password: @password)
        end

        test "image_url is the authenticated attachments path, not a storage URL" do
          dictionary = create(:dictionary)
          dictionary.image.attach(io: StringIO.new("fake image bytes"), filename: "fish.png", content_type: "image/png")

          get "/api/v1/admin/dictionaries/#{dictionary.id}", headers: @headers

          assert_response :ok
          image_url = response.parsed_body["data"]["image_url"]

          assert_equal "/api/v1/attachments/#{dictionary.image.blob.signed_id}", image_url
        end

        test "image_url is nil when no image is attached" do
          dictionary = create(:dictionary)

          get "/api/v1/admin/dictionaries/#{dictionary.id}", headers: @headers

          assert_response :ok
          assert_nil response.parsed_body["data"]["image_url"]
        end

        test "the officer who opens a species can fetch its picture through the image_url path" do
          dictionary = create(:dictionary)
          dictionary.image.attach(io: StringIO.new(png_bytes), filename: "fish.png", content_type: "image/png")

          get "/api/v1/admin/dictionaries/#{dictionary.id}", headers: @headers
          get response.parsed_body.dig("data", "image_url"), headers: @headers

          assert_response :ok
          assert_equal png_bytes, response.body.b
        end

        # The list carries image_url, but the picture itself is authorized by dictionaries.view: a role with only
        # dictionaries.list sees the path and is refused its bytes.
        test "an officer with only dictionaries.list sees image_url but is forbidden the picture" do
          dictionary = create(:dictionary)
          dictionary.image.attach(io: StringIO.new(png_bytes), filename: "fish.png", content_type: "image/png")
          headers = auth_headers_for(officer_with("dictionaries.list"), password: @password)

          get "/api/v1/admin/dictionaries", headers: headers
          get response.parsed_body.dig("data", 0, "image_url"), headers: headers

          assert_response :forbidden
        end

        # The documented bulk form, `dictionaries[][local_name]`, reaches Rails as an Array of entries.
        test "bulk create with dictionaries[][...] keeps every picture" do
          group = create(:dictionary_group)
          family = create(:dictionary_family, dictionary_group: group)
          entries = %w[Tenggiri Kembung].map do |name|
            { local_name: name, dictionary_group_id: group.id, dictionary_family_id: family.id,
              image: png_upload("#{name}.png") }
          end

          post "/api/v1/admin/dictionaries", params: { dictionaries: entries },
                                             headers: auth_headers_for(officer_with("dictionaries.create"),
                                                                       password: @password)

          assert_response :created
          assert_equal([true, true], response.parsed_body["data"].map { |entry| entry["image_url"].present? })
        end

        private

        def officer_with(*codes)
          permissions = codes.map { |code| Permission.find_or_create_by!(code:) { |p| p.name = code } }
          role = create(:role, permissions:)
          create(:user, role:, position: "Administrator", unit: "HQ",
                        password: @password, password_confirmation: @password)
        end

        def png_upload(name)
          Rack::Test::UploadedFile.new(StringIO.new(png_bytes), "image/png", original_filename: name)
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
end
