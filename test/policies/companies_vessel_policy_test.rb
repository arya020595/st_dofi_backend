require "test_helper"

class CompaniesVesselPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view another company's vessel" do
    permission = create(:permission, code: "companies_vessels.view")
    owning_company = create(:company_profile)
    other_vessel = create(:companies_vessel, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompaniesVesselPolicy.new(fisherman, other_vessel).show?
  end

  test "fisherman cannot update another company's vessel" do
    permission = create(:permission, code: "companies_vessels.update")
    owning_company = create(:company_profile)
    other_vessel = create(:companies_vessel, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompaniesVesselPolicy.new(fisherman, other_vessel).update?
  end

  test "fisherman cannot attach images to another company's vessel" do
    permission = create(:permission, code: "companies_vessels.images")
    owning_company = create(:company_profile)
    other_vessel = create(:companies_vessel, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompaniesVesselPolicy.new(fisherman, other_vessel).images?
  end

  test "fisherman can view their own company's vessel" do
    company = create(:company_profile)
    permission = create(:permission, code: "companies_vessels.view")
    vessel = create(:companies_vessel, company_profile: company)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate CompaniesVesselPolicy.new(fisherman, vessel), :show?
  end

  test "dofi officer can view any company's vessel" do
    permission = create(:permission, code: "companies_vessels.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    vessel = create(:companies_vessel)

    assert_predicate CompaniesVesselPolicy.new(officer, vessel), :show?
  end
end
