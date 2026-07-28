require "test_helper"

module Dictionaries
  class CreateTest < ActiveSupport::TestCase
    test "rejects an upload whose real bytes don't match its claimed content type" do
      # Ambiguous bytes (plain text with no distinguishing magic number) fall back to trusting the
      # filename extension — that's Marcel's documented behavior, not a gap. The property this test
      # protects is the one the handbook cares about: a strongly-signatured payload (HTML, capable
      # of carrying a script) must be caught by its real bytes regardless of what it's named.
      tempfile = Tempfile.new(["fake", ".png"])
      tempfile.write("<!DOCTYPE html><script>alert(document.cookie)</script>")
      tempfile.rewind
      spoofed_file = ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: "fake.png", type: "image/png")

      result = Create.call([{ local_name: "Spoofed Fish", image: spoofed_file }])

      assert_predicate result, :failure?
      assert_includes result.failure.errors.full_messages.join, "must be a JPEG, PNG, or WebP"
    ensure
      tempfile&.close!
    end

    test "accepts an upload whose real bytes match its claimed content type" do
      png_bytes = Base64.decode64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      )
      tempfile = Tempfile.new(["real", ".png"])
      tempfile.binmode
      tempfile.write(png_bytes)
      tempfile.rewind
      real_file = ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: "real.png", type: "image/png")

      result = Create.call([{ local_name: "Real Fish", image: real_file }])

      assert_predicate result, :success?
      assert_equal "image/png", result.value!.first.image.blob.content_type
    ensure
      tempfile&.close!
    end
  end
end
