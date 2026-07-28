require "test_helper"

module Attachments
  class PublicUrlTest < ActiveSupport::TestCase
    test "signs against the minio_public service, not the blob's own, when the blob is on minio" do
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "a.pdf",
                                                    content_type: "application/pdf")
      # update_column, not update! — ActiveStorage::Blob validates a changed service_name by
      # calling services.fetch(name), which *constructs* the real service (not a plain lookup).
      # For an S3 service that means eagerly building a real Aws::S3::Client, which under test
      # env's blank credentials falls through to AWS's instance-metadata credential chain and
      # hangs/fails. update_column sidesteps the callback entirely — deliberate, not laziness.
      # rubocop:disable Rails/SkipsModelValidations
      blob.update_column(:service_name, "minio")
      # rubocop:enable Rails/SkipsModelValidations
      fake_service = RecordingServiceDouble.new("https://signed.example/a.pdf")

      result = stub_fetched_service(:minio_public, fake_service) { PublicUrl.call(blob) }

      assert_equal "https://signed.example/a.pdf", result
      assert_equal blob.key, fake_service.captured_key
      assert_equal({ expires_in: PublicUrl::EXPIRES_IN, disposition: "inline", filename: blob.filename,
                     content_type: blob.content_type }, fake_service.captured_options)
    end

    test "falls back to the blob's own service when it isn't on minio" do
      ActiveStorage::Current.url_options = { host: "test.host" }
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "a.pdf",
                                                    content_type: "application/pdf")

      result = PublicUrl.call(blob)

      assert_includes result, "/rails/active_storage/disk/"
    end
  end
end
