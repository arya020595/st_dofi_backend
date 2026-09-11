require "test_helper"

class CompaniesFishingGearPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view another company's fishing gear" do
    permission = create(:permission, code: "companies_fishing_gears.view")
    owning_company = create(:company_profile)
    other_gear = create(:companies_fishing_gear, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompaniesFishingGearPolicy.new(fisherman, other_gear).show?
  end

  test "fisherman cannot destroy another company's fishing gear" do
    permission = create(:permission, code: "companies_fishing_gears.delete")
    owning_company = create(:company_profile)
    other_gear = create(:companies_fishing_gear, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CompaniesFishingGearPolicy.new(fisherman, other_gear).destroy?
  end

  test "fisherman can view their own company's fishing gear" do
    company = create(:company_profile)
    permission = create(:permission, code: "companies_fishing_gears.view")
    gear = create(:companies_fishing_gear, company_profile: company)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate CompaniesFishingGearPolicy.new(fisherman, gear), :show?
  end

  test "dofi officer can view any company's fishing gear" do
    permission = create(:permission, code: "companies_fishing_gears.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    gear = create(:companies_fishing_gear)

    assert_predicate CompaniesFishingGearPolicy.new(officer, gear), :show?
  end
end
