require "test_helper"

class ExternalUserPolicyTest < ActiveSupport::TestCase
  setup do
    permissions = %w[update delete].map { |action| create(:permission, code: "external_users.#{action}") }
    @officer = create(:user, :officer_shaped, role: create(:role, permissions:))
    @jetty_manager = create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER))
    @fisherman = create(:user, :profiled_fisherman)
  end

  test "update and destroy are allowed for a kept jetty manager" do
    policy = ExternalUserPolicy.new(@officer, @jetty_manager)

    assert_predicate policy, :update?
    assert_predicate policy, :destroy?
  end

  test "update and destroy are refused for a fisherman account even with the capability" do
    policy = ExternalUserPolicy.new(@officer, @fisherman)

    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "jetty manager scope shows only kept jetty managers" do
    discarded = create(:user, :jetty_manager_shaped, role: @jetty_manager.role)
    discarded.discard

    assert_equal [@jetty_manager.id], resolve(ExternalUserPolicy::JettyManagerScope).pluck(:id)
  end

  test "fisherman scope shows only DoFI-profiled owner/admin fishermen" do
    teammate_role = create(:role, :fisherman, company_profile: @fisherman.company_profile)
    create(:user, role: teammate_role, company_profile: @fisherman.company_profile, ic_number: "01-555555",
                  registration_type: "Commercial", provisioning_source: ::Fisherman::ProvisionUser::FISHERMAN_OWNER)

    assert_equal [@fisherman.id], resolve(ExternalUserPolicy::FishermanScope).pluck(:id)
  end

  private

  def resolve(scope_class)
    scope_class.new(@officer, User).resolve
  end
end
