require "test_helper"

module Users
  class JettyManagerRegistrationGuardTest < ActiveSupport::TestCase
    test "approve rejects a DoFi Officer account despite sharing the dofi_officer platform" do
      officer = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER))

      result = Users::ApproveRegistration.call(user: officer, actor: create(:user, :officer_shaped))

      assert_equal :not_fins_governed_jetty_manager, result.failure
    end

    test "reject rejects a DoFi Officer account despite sharing the dofi_officer platform" do
      officer = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER))
      remark = create(:approval_remark, usage_scope: "reject")

      result = Users::RejectRegistration.call(officer, approval_remark_id: remark.id,
                                                       actor: create(:user, :officer_shaped))

      assert_equal :not_fins_governed_jetty_manager, result.failure
    end

    test "deactivate rejects a DoFi Officer account despite sharing the dofi_officer platform" do
      officer = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER))

      result = Users::DeactivateRegistration.call(user: officer, actor: create(:user, :officer_shaped))

      assert_equal :not_fins_governed_jetty_manager, result.failure
    end

    test "reactivate rejects a DoFi Officer account despite sharing the dofi_officer platform" do
      officer = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER))

      result = Users::ReactivateRegistration.call(user: officer, actor: create(:user, :officer_shaped))

      assert_equal :not_fins_governed_jetty_manager, result.failure
    end

    test "revoke rejects a DoFi Officer account despite sharing the dofi_officer platform" do
      officer = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER))
      remark = create(:approval_remark, usage_scope: "revoke")

      result = Users::RevokeRegistration.call(user: officer, actor: create(:user, :officer_shaped),
                                              approval_remark_id: remark.id)

      assert_equal :not_fins_governed_jetty_manager, result.failure
    end
  end
end
