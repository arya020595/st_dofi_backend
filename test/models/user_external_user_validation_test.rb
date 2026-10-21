require "test_helper"

# Validation rules for Jetty Manager/Fisherman accounts that the officer-side External Users screen
# relies on: IC numbers are unique across every kept user, and a Jetty Manager (created only by a DoFi
# Officer) needs ic_number/unit/position but not contact_no.
class UserExternalUserValidationTest < ActiveSupport::TestCase
  test "a jetty manager is valid without contact_no" do
    jetty_manager = build(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER),
                                                        contact_no: nil)

    assert_predicate jetty_manager, :valid?
  end

  test "reports a kept user's IC number as already used, regardless of formatting" do
    create(:user, ic_number: "01-109878")
    user = build(:user, ic_number: "01 109878")

    assert_not user.valid?
    assert_includes user.errors.full_messages, "IC number is already used by another user"
  end
end
