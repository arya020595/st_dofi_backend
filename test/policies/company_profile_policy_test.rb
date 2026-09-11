require "test_helper"

class CompanyProfilePolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view another company's profile" do
    permission = create(:permission, code: "company_profiles.view")
    owning_company = create(:company_profile)
    other_company = create(:company_profile)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompanyProfilePolicy.new(fisherman, other_company).show?
  end

  test "fisherman cannot update another company's profile" do
    permission = create(:permission, code: "company_profiles.update")
    owning_company = create(:company_profile)
    other_company = create(:company_profile)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompanyProfilePolicy.new(fisherman, other_company).update?
  end

  test "fisherman can view their own company's profile" do
    company = create(:company_profile)
    permission = create(:permission, code: "company_profiles.view")
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate CompanyProfilePolicy.new(fisherman, company), :show?
  end

  test "dofi officer can view any company's profile" do
    permission = create(:permission, code: "company_profiles.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    company = create(:company_profile)

    assert_predicate CompanyProfilePolicy.new(officer, company), :show?
  end
end
