require "test_helper"

class ManifestMinorFishermanPolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view a minor fisherman on another company's manifest" do
    permission = create(:permission, code: "manifest_minor_fishermen.view")
    owning_company = create(:company_profile)
    other_manifest = create(:manifest, company_profile: create(:company_profile))
    minor = create(:manifest_minor_fisherman, manifest: other_manifest)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not ManifestMinorFishermanPolicy.new(fisherman, minor).show?
  end

  test "fisherman cannot destroy a minor fisherman on another company's manifest" do
    permission = create(:permission, code: "manifest_minor_fishermen.delete")
    owning_company = create(:company_profile)
    other_manifest = create(:manifest, company_profile: create(:company_profile))
    minor = create(:manifest_minor_fisherman, manifest: other_manifest)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not ManifestMinorFishermanPolicy.new(fisherman, minor).destroy?
  end

  test "fisherman can view a minor fisherman on their own company's manifest" do
    company = create(:company_profile)
    permission = create(:permission, code: "manifest_minor_fishermen.view")
    manifest = create(:manifest, company_profile: company)
    minor = create(:manifest_minor_fisherman, manifest: manifest)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate ManifestMinorFishermanPolicy.new(fisherman, minor), :show?
  end

  test "dofi officer can view a minor fisherman on any company's manifest" do
    permission = create(:permission, code: "manifest_minor_fishermen.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    minor = create(:manifest_minor_fisherman)

    assert_predicate ManifestMinorFishermanPolicy.new(officer, minor), :show?
  end
end
