require "test_helper"

module Attachments
  class AssetUrlTest < ActiveSupport::TestCase
    test "signs against the minio_assets_public service, not the blob's own, when the blob is on minio_assets" do
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "fish.png",
                                                    content_type: "image/png")
      # See the comment in public_url_test.rb — update_column sidesteps ActiveStorage::Blob's own
      # service_name validation, which would otherwise eagerly construct a real S3 client here.
      # rubocop:disable Rails/SkipsModelValidations
      blob.update_column(:service_name, "minio_assets")
      # rubocop:enable Rails/SkipsModelValidations
      fake_service = RecordingServiceDouble.new("https://assets.example/fish.png")

      result = stub_fetched_service(:minio_assets_public, fake_service) { AssetUrl.call(blob) }

      assert_equal "https://assets.example/fish.png", result
      assert_equal blob.key, fake_service.captured_key
      assert_equal({ expires_in: nil, disposition: "inline", filename: blob.filename,
                     content_type: blob.content_type }, fake_service.captured_options)
    end

    test "falls back to the blob's own service when it isn't on minio_assets" do
      ActiveStorage::Current.url_options = { host: "test.host" }
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "fish.png",
                                                    content_type: "image/png")

      result = AssetUrl.call(blob)

      assert_includes result, "/rails/active_storage/disk/"
    end
  end
end
