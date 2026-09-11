require "test_helper"

class CompaniesDocumentPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view another company's document" do
    permission = create(:permission, code: "companies_documents.view")
    owning_company = create(:company_profile)
    other_document = create(:companies_document, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompaniesDocumentPolicy.new(fisherman, other_document).show?
  end

  test "fisherman cannot update another company's document" do
    permission = create(:permission, code: "companies_documents.update")
    owning_company = create(:company_profile)
    other_document = create(:companies_document, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompaniesDocumentPolicy.new(fisherman, other_document).update?
  end

  test "fisherman can view their own company's document" do
    company = create(:company_profile)
    permission = create(:permission, code: "companies_documents.view")
    document = create(:companies_document, company_profile: company)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate CompaniesDocumentPolicy.new(fisherman, document), :show?
  end

  test "dofi officer can view any company's document" do
    permission = create(:permission, code: "companies_documents.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    document = create(:companies_document)

    assert_predicate CompaniesDocumentPolicy.new(officer, document), :show?
  end
end
