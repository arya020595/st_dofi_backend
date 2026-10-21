require "test_helper"

module CompaniesDocuments
  class UpdateTest < ActiveSupport::TestCase
    test "replaces the file and reverts approval_status to pending" do
      document = create(:companies_document, :approved)
      pdf_bytes = Rails.root.join("test/fixtures/files/sample.pdf").binread
      tempfile = Tempfile.new(["replacement", ".pdf"])
      tempfile.binmode
      tempfile.write(pdf_bytes)
      tempfile.rewind
      new_file = ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: "replacement.pdf",
                                                        type: "application/pdf")

      result = Update.call(document, new_file)

      assert_predicate result, :success?
      assert_equal "pending", document.reload.approval_status
    ensure
      tempfile&.close!
    end

    test "does not replace the file when the upload is not a PDF" do
      document = create(:companies_document, :approved)
      original_blob_key = document.file.blob.key
      tempfile = Tempfile.new(["fake", ".pdf"])
      tempfile.write("<!DOCTYPE html><script>alert(document.cookie)</script>")
      tempfile.rewind
      spoofed_file = ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: "fake.pdf",
                                                            type: "application/pdf")

      result = Update.call(document, spoofed_file)

      assert_predicate result, :failure?
      assert_equal "approved", document.reload.approval_status
      assert_equal original_blob_key, document.file.blob.key
    ensure
      tempfile&.close!
    end
  end
end
