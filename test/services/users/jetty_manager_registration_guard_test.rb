require "test_helper"

module Users
  class JettyManagerRegistrationGuardTest < ActiveSupport::TestCase
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
  end
end
