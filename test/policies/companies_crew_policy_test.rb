require "test_helper"

class CompaniesCrewPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view another company's crew" do
    permission = create(:permission, code: "companies_crews.view")
    owning_company = create(:company_profile)
    other_crew = create(:companies_crew, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompaniesCrewPolicy.new(fisherman, other_crew).show?
  end

  test "fisherman cannot destroy another company's crew" do
    permission = create(:permission, code: "companies_crews.delete")
    owning_company = create(:company_profile)
    other_crew = create(:companies_crew, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompaniesCrewPolicy.new(fisherman, other_crew).destroy?
  end

  test "fisherman can view their own company's crew" do
    company = create(:company_profile)
    permission = create(:permission, code: "companies_crews.view")
    crew = create(:companies_crew, company_profile: company)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate CompaniesCrewPolicy.new(fisherman, crew), :show?
  end

  test "dofi officer can view any company's crew" do
    permission = create(:permission, code: "companies_crews.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    crew = create(:companies_crew)

    assert_predicate CompaniesCrewPolicy.new(officer, crew), :show?
  end
end
