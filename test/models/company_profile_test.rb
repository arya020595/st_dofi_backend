require "test_helper"

class CompanyProfileTest < ActiveSupport::TestCase
  test "invalid without the newly-required profiling fields" do
    profile = build(:company_profile, gender: nil, ic_colour: nil, worker_quota: nil)
    profile.valid?

    assert_includes profile.errors.attribute_names, :gender
    assert_includes profile.errors.attribute_names, :ic_colour
    assert_includes profile.errors.attribute_names, :worker_quota
  end

  test "sibling finds the other profile sharing the same rocbn_no and company_name" do
    owner = create(:company_profile, rocbn_no: "RC-PAIR", company_name: "Pair Co", designation: "Owner")
    admin = create(:company_profile, rocbn_no: "RC-PAIR", company_name: "Pair Co", designation: "Admin")

    assert_equal admin, owner.sibling
    assert_equal owner, admin.sibling
  end

  test "sibling is nil when rocbn_no is blank" do
    profile = create(:company_profile, rocbn_no: nil)

    assert_nil profile.sibling
  end

  test "sibling is nil when no other profile shares the same rocbn_no" do
    profile = create(:company_profile, rocbn_no: "RC-LONE")

    assert_nil profile.sibling
  end
end
