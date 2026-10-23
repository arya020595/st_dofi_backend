require "test_helper"

class RocbnCompanyPolicyTest < ActiveSupport::TestCase
  setup do
    @lister = officer_with(%w[list])
    @viewer = officer_with(%w[view])
    @fisherman = create(:user, role: create(:role, :fisherman), ic_number: SecureRandom.hex(5),
                               registration_type: "Commercial")
  end

  test "the list permission allows searching, not fetching one company" do
    policy = RocbnCompanyPolicy.new(@lister, Rocbn::Company)

    assert_predicate policy, :index?
    assert_not_predicate policy, :show?
  end

  test "the view permission allows fetching one company, not searching" do
    policy = RocbnCompanyPolicy.new(@viewer, Rocbn::Company)

    assert_predicate policy, :show?
    assert_not_predicate policy, :index?
  end

  test "the lookup grants nothing beyond reading" do
    policy = RocbnCompanyPolicy.new(officer_with(%w[list view]), Rocbn::Company)

    assert_not_predicate policy, :create?
    assert_not_predicate policy, :update?
    assert_not_predicate policy, :destroy?
  end

  test "officers see the registry's kept rows, anyone else sees none" do
    registry = Struct.new(:kept, :none).new(:kept_rows, :no_rows)

    assert_equal :kept_rows, RocbnCompanyPolicy::Scope.new(@lister, registry).resolve
    assert_equal :no_rows, RocbnCompanyPolicy::Scope.new(@fisherman, registry).resolve
  end

  private

  def officer_with(actions)
    permissions = actions.map do |action|
      Permission.find_or_create_by!(code: "rocbn_companies.#{action}") { |permission| permission.name = action }
    end
    create(:user, :officer_shaped, role: create(:role, permissions: permissions))
  end
end
