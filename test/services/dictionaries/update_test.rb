require "test_helper"

module Dictionaries
  class UpdateTest < ActiveSupport::TestCase
    test "uploads a new image and attaches it" do
      dictionary = create(:dictionary)

      result = Update.call(dictionary, image: uploaded("real.png", png_bytes))

      assert_predicate result, :success?
      assert_equal "image/png", dictionary.reload.image.blob.content_type
      assert_equal png_bytes, dictionary.image.download
    end

    test "rejects an upload whose real bytes don't match its claimed content type" do
      dictionary = create(:dictionary, local_name: "Before")

      result = Update.call(dictionary, local_name: "After",
                                       image: uploaded("fake.png", "<!DOCTYPE html><script>alert(1)</script>"))

      assert_predicate result, :failure?
      assert_includes dictionary.errors.full_messages.join, "must be a JPEG, PNG, or WebP"
    end

    test "a rejected upload leaves the record and its image untouched" do
      dictionary = create(:dictionary, local_name: "Before")

      html = "<!DOCTYPE html><script>alert(1)</script>"
      Update.call(dictionary, local_name: "After", image: uploaded("fake.png", html))

      assert_equal "Before", dictionary.reload.local_name
      assert_not_predicate dictionary.image, :attached?
    end

    private

    def uploaded(name, bytes)
      tempfile = Tempfile.new(["upload", File.extname(name)])
      tempfile.binmode
      tempfile.write(bytes)
      tempfile.rewind
      @tempfiles = (@tempfiles || []) << tempfile
      ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: name, type: "image/png")
    end

    def teardown
      @tempfiles&.each(&:close!)
    end

    def png_bytes
      Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")
    end
  end
end
