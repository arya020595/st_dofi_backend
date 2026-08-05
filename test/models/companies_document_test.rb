require "test_helper"

class CompaniesDocumentTest < ActiveSupport::TestCase
  test "approve! transitions pending to approved and stamps the approver" do
    officer = create(:user)
    document = create(:companies_document)

    document.approve!(actor: officer)

    assert_equal "approved", document.approval_status
    assert_equal officer.id, document.approved_by_id
    assert_not_nil document.approved_at
  end

  test "approve! raises when the document is not pending" do
    document = create(:companies_document, :approved)

    assert_raises(AASM::InvalidTransition) { document.approve! }
    assert_not document.may_approve?
  end

  test "request_amendment! moves to amendment_required and records the remarks" do
    document = create(:companies_document)

    document.request_amendment!(remarks: "Scan is illegible")

    assert_equal "amendment_required", document.approval_status
    assert_equal "Scan is illegible", document.amendment_remarks
  end

  test "resubmit! cycles an amended document back to pending, clearing amendment_remarks" do
    document = create(:companies_document)
    document.request_amendment!(remarks: "Scan is illegible")

    document.resubmit!

    assert_equal "pending", document.approval_status
    assert_nil document.amendment_remarks
  end

  test "is invalid with a document_type outside the allowed list" do
    document = build(:companies_document, document_type: "something_else")

    assert_not document.valid?
    assert_includes document.errors.attribute_names, :document_type
  end

  test "is invalid without a file attached" do
    document = CompaniesDocument.new(company_profile: create(:company_profile), document_type: "white_card")

    assert_not document.valid?
    assert_includes document.errors.attribute_names, :file
  end

  test "is invalid when the attached file is not a PDF" do
    document = build(:companies_document)
    document.file.attach(io: StringIO.new("not a pdf"), filename: "fake.pdf", content_type: "image/png")

    assert_not document.valid?
    assert_includes document.errors[:file], "must be a PDF"
  end

  test "is invalid when the attached file exceeds the max size" do
    document = build(:companies_document)
    document.file.attach(io: StringIO.new("x" * (CompaniesDocument::MAX_FILE_SIZE + 1)), filename: "big.pdf",
                         content_type: "application/pdf")

    assert_not document.valid?
    assert_includes document.errors[:file], "must be smaller than 10 MB"
  end

  test "allows the same document_type to be reused after the original is discarded" do
    document = create(:companies_document, document_type: "white_card")
    document.discard!

    new_document = build(:companies_document, company_profile: document.company_profile, document_type: "white_card")

    assert_predicate new_document, :valid?
  end
end

# == Schema Information
#
# Table name: companies_documents
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  amendment_remarks  :text
#  approval_status    :string           default("pending"), not null
#  approved_at        :datetime
#  discarded_at       :datetime
#  document_type      :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  approved_by_id     :uuid
#  company_profile_id :uuid             not null
#
# Indexes
#
#  index_companies_documents_on_approved_by_id         (approved_by_id)
#  index_companies_documents_on_company_profile_id     (company_profile_id)
#  index_companies_documents_on_discarded_at           (discarded_at)
#  index_companies_documents_on_profile_and_type_kept  (company_profile_id,document_type) UNIQUE WHERE (discarded_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
