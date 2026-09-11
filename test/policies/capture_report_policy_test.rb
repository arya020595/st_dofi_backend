require "test_helper"

class CaptureReportPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view a capture report on another company's manifest" do
    permission = create(:permission, code: "capture_reports.view")
    owning_company = create(:company_profile)
    other_report = create(:capture_report, manifest: create(:manifest, company_profile: create(:company_profile)))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CaptureReportPolicy.new(fisherman, other_report).show?
  end

  test "fisherman cannot resubmit a capture report on another company's manifest" do
    permission = create(:permission, code: "capture_reports.resubmit")
    owning_company = create(:company_profile)
    other_report = create(:capture_report, manifest: create(:manifest, company_profile: create(:company_profile)))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not CaptureReportPolicy.new(fisherman, other_report).resubmit?
  end

  test "fisherman can view a capture report on their own company's manifest" do
    company = create(:company_profile)
    permission = create(:permission, code: "capture_reports.view")
    report = create(:capture_report, manifest: create(:manifest, company_profile: company))
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate CaptureReportPolicy.new(fisherman, report), :show?
  end

  test "dofi officer can view a capture report on any company's manifest" do
    permission = create(:permission, code: "capture_reports.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    report = create(:capture_report)

    assert_predicate CaptureReportPolicy.new(officer, report), :show?
  end
end
