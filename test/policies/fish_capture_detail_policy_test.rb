require "test_helper"

class FishCaptureDetailPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view a fish capture detail on another company's manifest" do
    permission = create(:permission, code: "fish_capture_details.view")
    owning_company = create(:company_profile)
    other_report = create(:capture_report, manifest: create(:manifest, company_profile: create(:company_profile)))
    other_detail = create(:fish_capture_detail, capture_report: other_report)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not FishCaptureDetailPolicy.new(fisherman, other_detail).show?
  end

  test "fisherman cannot destroy a fish capture detail on another company's manifest" do
    permission = create(:permission, code: "fish_capture_details.delete")
    owning_company = create(:company_profile)
    other_report = create(:capture_report, manifest: create(:manifest, company_profile: create(:company_profile)))
    other_detail = create(:fish_capture_detail, capture_report: other_report)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not FishCaptureDetailPolicy.new(fisherman, other_detail).destroy?
  end

  test "fisherman can view a fish capture detail on their own company's manifest" do
    company = create(:company_profile)
    permission = create(:permission, code: "fish_capture_details.view")
    report = create(:capture_report, manifest: create(:manifest, company_profile: company))
    detail = create(:fish_capture_detail, capture_report: report)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate FishCaptureDetailPolicy.new(fisherman, detail), :show?
  end

  test "dofi officer can view a fish capture detail on any company's manifest" do
    permission = create(:permission, code: "fish_capture_details.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    detail = create(:fish_capture_detail)

    assert_predicate FishCaptureDetailPolicy.new(officer, detail), :show?
  end
end
