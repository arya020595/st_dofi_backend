require "test_helper"

class FishingGearDetailPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view a fishing gear detail on another company's manifest" do
    permission = create(:permission, code: "fishing_gear_details.view")
    owning_company = create(:company_profile)
    other_report = create(:capture_report, manifest: create(:manifest, company_profile: create(:company_profile)))
    other_detail = create(:fishing_gear_detail, capture_report: other_report)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not FishingGearDetailPolicy.new(fisherman, other_detail).show?
  end

  test "fisherman cannot destroy a fishing gear detail on another company's manifest" do
    permission = create(:permission, code: "fishing_gear_details.delete")
    owning_company = create(:company_profile)
    other_report = create(:capture_report, manifest: create(:manifest, company_profile: create(:company_profile)))
    other_detail = create(:fishing_gear_detail, capture_report: other_report)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not FishingGearDetailPolicy.new(fisherman, other_detail).destroy?
  end

  test "fisherman can view a fishing gear detail on their own company's manifest" do
    company = create(:company_profile)
    permission = create(:permission, code: "fishing_gear_details.view")
    report = create(:capture_report, manifest: create(:manifest, company_profile: company))
    detail = create(:fishing_gear_detail, capture_report: report)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate FishingGearDetailPolicy.new(fisherman, detail), :show?
  end

  test "dofi officer can view a fishing gear detail on any company's manifest" do
    permission = create(:permission, code: "fishing_gear_details.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    detail = create(:fishing_gear_detail)

    assert_predicate FishingGearDetailPolicy.new(officer, detail), :show?
  end
end
