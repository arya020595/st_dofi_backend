require "test_helper"

module Admin
  class AccountsQueryTest < ActiveSupport::TestCase
    test "filters by category" do
      fisherman = create_fisherman_account
      role = create_jetty_manager_role
      create(:user, :jetty_manager_shaped, role:)

      result = ::Admin::AccountsQuery.call(scope: User.all, category: "fisherman_account", status_values: [])

      assert_equal [fisherman.id], result.map(&:id)
    end

    test "filters fisherman accounts by lifecycle status" do
      active_fisherman = create_fisherman_account(fisherman_status: "active")
      create_fisherman_account(fisherman_status: "suspended")

      result = ::Admin::AccountsQuery.call(scope: User.all, category: "fisherman_account", status_values: ["active"])

      assert_equal [active_fisherman.id], result.map(&:id)
    end

    test "filters jetty manager accounts by status directly" do
      role = create_jetty_manager_role
      active_jetty_manager = create(:user, :jetty_manager_shaped, role:, status: "active")
      inactive_jetty_manager = create(:user, :jetty_manager_shaped, role:, status: "inactive")

      result = ::Admin::AccountsQuery.call(scope: User.all, category: "jetty_manager_account",
                                           status_values: ["inactive"])

      assert_equal [inactive_jetty_manager.id], result.map(&:id)
      assert_not_includes result.map(&:id), active_jetty_manager.id
    end

    test "filters across categories by status when no category is given" do
      active_fisherman = create_fisherman_account(fisherman_status: "active")
      role = create_jetty_manager_role
      inactive_jetty_manager = create(:user, :jetty_manager_shaped, role:, status: "inactive")

      result = ::Admin::AccountsQuery.call(scope: User.joins(:role), category: nil, status_values: %w[active inactive])

      assert_equal [active_fisherman.id, inactive_jetty_manager.id].sort, result.map(&:id).sort
    end

    private

    def create_fisherman_account(fisherman_status: nil, **user_attrs)
      role = create(:role, :fisherman, is_default: true, name: "Owner")
      claim_attrs = if fisherman_status == "active"
                      { claimed_at: Time.current, brunei_id_verified_at: Time.current }
                    else
                      {}
                    end
      create(:user, role:, ic_number: next_ic_number, registration_type: "Commercial", fisherman_status:,
                    **claim_attrs, **user_attrs)
    end

    def create_jetty_manager_role
      create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
    end

    def next_ic_number
      @ic_sequence = (@ic_sequence || 0) + 1
      format("31-%07d", @ic_sequence)
    end
  end
end
