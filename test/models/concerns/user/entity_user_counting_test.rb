require "test_helper"

class EntityUserCountingTest < ActiveSupport::TestCase
  test "entity_user_count tracks create, discard, and undiscard" do
    company_profile, user = create_company_profile_fisherman

    assert_equal 1, company_profile.reload.entity_user_count

    user.discard

    assert_equal 0, company_profile.reload.entity_user_count

    user.undiscard

    assert_equal 1, company_profile.reload.entity_user_count
  end

  test "entity_user_count is untouched for users without a company profile" do
    officer_role = create(:role, kind: Role::DOFI_OFFICER)

    assert_nothing_raised { create(:user, :officer_shaped, role: officer_role, company_profile: nil) }
  end

  private

  def create_company_profile_fisherman
    company_profile = create(:company_profile)
    role = create(:role, :fisherman, company_profile: company_profile)
    user = create(:user, role: role, company_profile: company_profile, ic_number: SecureRandom.hex(5),
                         registration_type: "Commercial")
    [company_profile, user]
  end
end
