require "test_helper"

module CompaniesDocuments
  class CreateTest < ActiveSupport::TestCase
    test "rejects an upload whose real bytes don't match its claimed content type" do
      tempfile = Tempfile.new(["fake", ".pdf"])
      tempfile.write("<!DOCTYPE html><script>alert(document.cookie)</script>")
      tempfile.rewind
      spoofed_file = ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: "fake.pdf",
                                                            type: "application/pdf")
      company_profile = create(:company_profile)

      result = Create.call(company_profile, { document_type: "white_card", file: spoofed_file })

      assert_predicate result, :failure?
      assert_includes result.failure.errors.full_messages.join, "must be a PDF"
    ensure
      tempfile&.close!
    end

    test "accepts an upload whose real bytes match its claimed content type" do
      pdf_bytes = Rails.root.join("test/fixtures/files/sample.pdf").binread
      tempfile = Tempfile.new(["real", ".pdf"])
      tempfile.binmode
      tempfile.write(pdf_bytes)
      tempfile.rewind
      real_file = ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: "real.pdf",
                                                         type: "application/pdf")
      company_profile = create(:company_profile)

      result = Create.call(company_profile, { document_type: "white_card", file: real_file })

      assert_predicate result, :success?
      assert_equal "application/pdf", result.value!.file.blob.content_type
    ensure
      tempfile&.close!
    end

    test "rejects an upload larger than the max file size" do
      tempfile = Tempfile.new(["big", ".pdf"])
      tempfile.write("x" * (CompaniesDocument::MAX_FILE_SIZE + 1))
      tempfile.rewind
      big_file = ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: "big.pdf",
                                                        type: "application/pdf")
      company_profile = create(:company_profile)

      result = Create.call(company_profile, { document_type: "white_card", file: big_file })

      assert_predicate result, :failure?
      assert_includes result.failure.errors.full_messages.join, "must be smaller than 10 MB"
    ensure
      tempfile&.close!
    end
  end
end
