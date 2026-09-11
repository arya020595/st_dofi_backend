require "test_helper"

class CompanyProfileContactPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot update another company's contact" do
    permission = create(:permission, code: "company_profile_contacts.update")
    owning_company = create(:company_profile)
    other_contact = create(:company_profile_contact, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompanyProfileContactPolicy.new(fisherman, other_contact).update?
  end

  test "fisherman cannot destroy another company's contact" do
    permission = create(:permission, code: "company_profile_contacts.delete")
    owning_company = create(:company_profile)
    other_contact = create(:company_profile_contact, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompanyProfileContactPolicy.new(fisherman, other_contact).destroy?
  end

  test "fisherman can update their own company's contact" do
    company = create(:company_profile)
    permission = create(:permission, code: "company_profile_contacts.update")
    contact = create(:company_profile_contact, company_profile: company)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate CompanyProfileContactPolicy.new(fisherman, contact), :update?
  end

  test "dofi officer can update any company's contact" do
    permission = create(:permission, code: "company_profile_contacts.update")
    officer = build(:user, role: create(:role, permissions: [permission]))
    contact = create(:company_profile_contact)

    assert_predicate CompanyProfileContactPolicy.new(officer, contact), :update?
  end
end
