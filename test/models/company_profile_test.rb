require "test_helper"

class CompanyProfileTest < ActiveSupport::TestCase
  test "invalid without worker_quota" do
    profile = build(:company_profile, worker_quota: nil)
    profile.valid?

    assert_includes profile.errors.attribute_names, :worker_quota
  end

  test "owner_contact and admin_contact find the kept contact with the matching designation" do
    company_profile = create(:company_profile)
    owner = create(:company_profile_contact, company_profile: company_profile, designation: "Owner")
    admin = create(:company_profile_contact, company_profile: company_profile, designation: "Admin")

    assert_equal owner, company_profile.owner_contact
    assert_equal admin, company_profile.admin_contact
  end

  test "owner_contact ignores discarded contacts" do
    company_profile = create(:company_profile)
    owner = create(:company_profile_contact, company_profile: company_profile, designation: "Owner")
    owner.discard

    assert_nil company_profile.owner_contact
  end

  test "admin_contact is nil when the company has no admin" do
    company_profile = create(:company_profile)
    create(:company_profile_contact, company_profile: company_profile, designation: "Owner")

    assert_nil company_profile.admin_contact
  end
end
