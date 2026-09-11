require "test_helper"

class ManifestPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view another company's manifest" do
    permission = create(:permission, code: "manifests.view")
    owning_company = create(:company_profile)
    other_manifest = create(:manifest, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not ManifestPolicy.new(fisherman, other_manifest).show?
  end

  test "fisherman cannot update another company's manifest" do
    permission = create(:permission, code: "manifests.update")
    owning_company = create(:company_profile)
    other_manifest = create(:manifest, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not ManifestPolicy.new(fisherman, other_manifest).update?
  end

  test "fisherman cannot skip capture report on another company's manifest" do
    permission = create(:permission, code: "manifests.skip_capture_report")
    owning_company = create(:company_profile)
    other_manifest = create(:manifest, company_profile: create(:company_profile))
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not ManifestPolicy.new(fisherman, other_manifest).skip_capture_report?
  end

  test "fisherman can view their own company's manifest" do
    company = create(:company_profile)
    permission = create(:permission, code: "manifests.view")
    manifest = create(:manifest, company_profile: company)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate ManifestPolicy.new(fisherman, manifest), :show?
  end

  test "dofi officer can view any company's manifest" do
    permission = create(:permission, code: "manifests.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    manifest = create(:manifest)

    assert_predicate ManifestPolicy.new(officer, manifest), :show?
  end
end
