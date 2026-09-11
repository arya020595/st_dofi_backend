require "test_helper"

class RbacContractTest < ActiveSupport::TestCase
  class PermissionProbe
    attr_reader :checked_codes

    def initialize(allowed_code: :all)
      @checked_codes = []
      @allowed_code = allowed_code
    end

    def permission?(code)
      @checked_codes << code
      allowed_code == :all || code == allowed_code
    end

    def dofi_officer_platform? = true
    def fisherman? = false
    def officer? = true
    def company_profile_id = "company-profile-id"
    def method_missing(*) = true # rubocop:disable Naming/PredicateMethod
    def respond_to_missing?(*) = true

    private

    attr_reader :allowed_code
  end

  class PermissiveRecord
    def initialize(resource)
      @resource = resource
    end

    # These names mirror the real domain API exercised by RolePolicy/UserPolicy.
    # rubocop:disable Naming/PredicatePrefix
    def is_default? = false
    def is_default_admin? = false
    def system_managed_fisherman_role? = false
    def has_fisherman_owner_role? = false
    # rubocop:enable Naming/PredicatePrefix
    def pending? = true
    def platform_scope = resource == "fisherman_roles" ? Role::FISHERMAN_PLATFORM : Role::DOFI_OFFICER_PLATFORM
    def company_profile_id = "company-profile-id"
    def role_id = nil
    def role = nil
    def method_missing(*) = true # rubocop:disable Naming/PredicateMethod
    def respond_to_missing?(*) = true

    private

    attr_reader :resource
  end

  ACTION_SUFFIX = {
    index?: "list", tab_counts?: "list", show?: "view", create?: "create", update?: "update", destroy?: "delete"
  }.freeze
  STANDARD_ACTIONS = {
    "list" => :index?, "view" => :show?, "create" => :create?, "update" => :update?, "delete" => :destroy?
  }.freeze

  test "every concrete policy directly defines one private canonical resource" do
    Rails.application.eager_load!
    failures = ApplicationPolicy.descendants.filter_map do |policy_class|
      unless policy_class.superclass == ApplicationPolicy
        next "#{policy_class} does not directly inherit ApplicationPolicy"
      end
      next "#{policy_class} inherits #permission_resource" \
        unless policy_class.instance_method(:permission_resource).owner == policy_class
      next "#{policy_class} exposes #permission_resource publicly" \
        unless policy_class.private_method_defined?(:permission_resource, false)

      resource = policy_resource(policy_class)
      unless Permission::Catalog::RESOURCES.key?(resource)
        next "#{policy_class} has unknown resource #{resource.inspect}"
      end

      nil
    end

    assert_empty failures, failures.join("\n")
  end

  test "every policy action checks only its canonical capability" do
    Rails.application.eager_load!
    failures = []

    ApplicationPolicy.descendants.each do |policy_class|
      resource = policy_resource(policy_class)
      policy_actions(policy_class, resource).each do |action|
        suffix = ACTION_SUFFIX.fetch(action, action.to_s.delete_suffix("?"))
        expected_code = "#{resource}.#{suffix}"
        exact_probe = PermissionProbe.new(allowed_code: expected_code)
        exact_result = policy_class.new(exact_probe, PermissiveRecord.new(resource)).public_send(action)
        wrong_result = policy_class.new(
          PermissionProbe.new(allowed_code: "unrelated.#{suffix}"), PermissiveRecord.new(resource)
        ).public_send(action)

        failures << "#{policy_class}##{action} checked #{exact_probe.checked_codes.inspect}" \
          unless exact_probe.checked_codes == [expected_code]
        failures << "#{expected_code} is absent from the catalog" unless Permission::Catalog.include?(expected_code)
        failures << "#{policy_class}##{action} rejected #{expected_code}" unless exact_result
        failures << "#{policy_class}##{action} accepted an unrelated resource" if wrong_result
      end
    end

    assert_empty failures, failures.join("\n")
  end

  test "catalog resources and concrete policies have a one-to-one mapping" do
    Rails.application.eager_load!
    policy_resources = ApplicationPolicy.descendants.map { |policy_class| policy_resource(policy_class) }
    duplicates = policy_resources.tally.select { |_resource, count| count > 1 }.keys

    assert_empty duplicates, "resources owned by multiple policies: #{duplicates.join(', ')}"
    assert_empty Permission::Catalog::RESOURCES.keys - policy_resources, "catalog resource has no policy"
  end

  test "admin and fisherman manifest access dispatches through the same action" do
    permission = create(:permission, code: "manifests.list")
    company = create(:company_profile)
    officer = build(:user, role: create(:role, permissions: [permission]))
    fisherman = build(:user, role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_equal [true, true], [ManifestPolicy.new(officer, Manifest).index?,
                                ManifestPolicy.new(fisherman, Manifest).index?]
  end

  test "manifest workflow resource is not exposed by ManifestPolicy" do
    assert_not ManifestPolicy.public_method_defined?(:approve_port_out?)
    assert_not ManifestPolicy.public_method_defined?(:request_amendment_port_out?)
  end

  test "verification resource is not exposed by CaptureReportPolicy" do
    assert_not CaptureReportPolicy.public_method_defined?(:verify?)
    assert_not CaptureReportPolicy.public_method_defined?(:request_amendment?)
  end

  test "missing permission resource fails closed" do
    assert_raises(NotImplementedError) do
      ApplicationPolicy.new(PermissionProbe.new, PermissiveRecord.new(nil)).index?
    end
  end

  private

  def policy_resource(policy_class)
    policy_class.new(PermissionProbe.new, PermissiveRecord.new(nil)).send(:permission_resource)
  end

  def policy_actions(policy_class, resource)
    catalog_actions = Permission::Catalog::RESOURCES.fetch(resource).map do |entry|
      action = entry.fetch(:action)
      STANDARD_ACTIONS.fetch(action, :"#{action}?")
    end
    aliases = policy_class.public_instance_methods(false).grep(/\?\z/)
    actions = (catalog_actions + aliases).uniq
    missing_action = actions.detect { |action| !policy_class.public_method_defined?(action) }
    flunk "#{policy_class} does not implement catalog action ##{missing_action}" if missing_action
    actions
  end
end

class RbacSourceContractTest < ActiveSupport::TestCase
  # This single repository scan deliberately asserts every forbidden syntax invariant together.
  # rubocop:disable Minitest/MultipleAssertions
  test "policy and controller sources contain no audience-specific policy actions or legacy fallbacks" do
    sources = Rails.root.glob("app/{policies,controllers}/**/*.rb").index_with(&:read)

    sources.each do |path, source|
      assert_no_match(/def fisherman_[a-z_]*\?/, source, path.to_s)
      assert_no_match(/authorize .*:fisherman_[a-z_]*\?/, source, path.to_s)
      assert_no_match(/def fisherman_(?:manifest|lookup|vessel)_[a-z_]*\?/, source, path.to_s)
      constant_values = source.scan(/^\s*[A-Z][A-Z0-9_]*\s*=\s*["']([^"']+)["']/).flatten

      assert_empty constant_values & Permission::Catalog::RESOURCES.keys, path.to_s
      if path.to_s.include?("/policies/") && path.basename.to_s != "application_policy.rb"
        assert_no_match(/user\.permission\?\s*\(/, source, path.to_s)
      end
      next unless path.basename.to_s.end_with?("_policy.rb") && path.basename.to_s != "application_policy.rb"

      assert_equal 1, source.scan(/\bdef permission_resource\b/).size, path.to_s
    end
  end
  # rubocop:enable Minitest/MultipleAssertions
end
