require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "approve! transitions a pending user to active" do
    user = create(:user, status: "pending")

    user.approve!

    assert_equal "active", user.status
  end

  test "approve! raises when the user is not pending" do
    user = create(:user, status: "active")

    assert_raises(AASM::InvalidTransition) { user.approve! }
    assert_not user.may_approve?
  end

  test "reject! transitions a pending user to rejected" do
    user = create(:user, status: "pending")

    user.reject!

    assert_equal "rejected", user.status
  end

  test "reject! raises when the user is not pending" do
    user = create(:user, status: "rejected")

    assert_raises(AASM::InvalidTransition) { user.reject! }
    assert_not user.may_reject?
  end

  test "approval_status_label maps AASM states to display labels" do
    assert_equal "Pending", build(:user, status: "pending").approval_status_label
    assert_equal "Approved", build(:user, status: "active").approval_status_label
    assert_equal "Rejected", build(:user, status: "rejected").approval_status_label
  end

  test "officer? is true only for the DoFi Officer role" do
    officer_role = create(:role, kind: Role::DOFI_OFFICER)
    jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER)

    assert_predicate build(:user, role: officer_role), :officer?
    assert_not build(:user, role: jetty_manager_role).officer?
    assert_not build(:user, role: nil).officer?
  end

  test "invalid without position, unit, or username for the DoFi Officer role" do
    officer_role = create(:role, kind: Role::DOFI_OFFICER)
    user = build(:user, role: officer_role, position: nil, unit: nil, username: nil)
    user.valid?

    assert_includes user.errors.attribute_names, :position
    assert_includes user.errors.attribute_names, :unit
    assert_includes user.errors.attribute_names, :username
  end

  test "email is never required, even for the DoFi Officer role" do
    officer_role = create(:role, kind: Role::DOFI_OFFICER)
    user = build(:user, role: officer_role, email: "", position: "Administrator", unit: "HQ")

    assert_predicate user, :valid?
  end
end
