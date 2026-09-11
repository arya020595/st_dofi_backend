require "test_helper"

class ManifestExpensePolicyTest < ActiveSupport::TestCase
  test "fisherman cannot view expense on another company's manifest" do
    permission = create(:permission, code: "manifest_expenses.view")
    owning_company = create(:company_profile)
    other_manifest = create(:manifest, company_profile: create(:company_profile))
    expense = create(:manifest_expense, manifest: other_manifest)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not ManifestExpensePolicy.new(fisherman, expense).show?
  end

  test "fisherman cannot update expense on another company's manifest" do
    permission = create(:permission, code: "manifest_expenses.update")
    owning_company = create(:company_profile)
    other_manifest = create(:manifest, company_profile: create(:company_profile))
    expense = create(:manifest_expense, manifest: other_manifest)
    fisherman = build(:user, company_profile: owning_company,
                             role: create(:role, :fisherman, company_profile: owning_company,
                                                             permissions: [permission]))

    assert_not ManifestExpensePolicy.new(fisherman, expense).update?
  end

  test "fisherman can view expense on their own company's manifest" do
    company = create(:company_profile)
    permission = create(:permission, code: "manifest_expenses.view")
    manifest = create(:manifest, company_profile: company)
    expense = create(:manifest_expense, manifest: manifest)
    fisherman = build(:user, company_profile: company,
                             role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_predicate ManifestExpensePolicy.new(fisherman, expense), :show?
  end

  test "dofi officer can view expense on any company's manifest" do
    permission = create(:permission, code: "manifest_expenses.view")
    officer = build(:user, role: create(:role, permissions: [permission]))
    expense = create(:manifest_expense)

    assert_predicate ManifestExpensePolicy.new(officer, expense), :show?
  end
end
