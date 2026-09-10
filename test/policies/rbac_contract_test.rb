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
    def method_missing(*) = true # rubocop:disable Naming/PredicateMethod
    def respond_to_missing?(*) = true

    private

    attr_reader :allowed_code
  end

  class PermissiveRecord
    # These names mirror the real domain API exercised by RolePolicy/UserPolicy.
    # rubocop:disable Naming/PredicatePrefix
    def is_default? = false
    def is_default_admin? = false
    def system_managed_fisherman_role? = false
    def has_fisherman_owner_role? = false
    # rubocop:enable Naming/PredicatePrefix
    def pending? = true
    def method_missing(*) = true # rubocop:disable Naming/PredicateMethod
    def respond_to_missing?(*) = true
  end

  ACTION_SUFFIX = {
    index?: "list", tab_counts?: "list", show?: "view", create?: "create", update?: "update",
    destroy?: "delete", approve_port_out?: "approve", approve_port_in?: "approve",
    request_amendment?: "amendment",
    request_amendment_port_out?: "amendment", request_amendment_port_in?: "amendment"
  }.freeze

  test "every policy action checks only its canonical capability" do
    Rails.application.eager_load!
    failures = []

    ApplicationPolicy.descendants.each do |policy_class|
      next if policy_class == PermissionPolicy

      policy_class.public_instance_methods(false).grep(/\?\z/).each do |action|
        resource = expected_resource(policy_class, action)
        suffix = ACTION_SUFFIX.fetch(action, action.to_s.delete_suffix("?"))
        expected_code = "#{resource}.#{suffix}"
        exact_probe = PermissionProbe.new(allowed_code: expected_code)
        exact_result = policy_class.new(exact_probe, PermissiveRecord.new).public_send(action)
        wrong_result = policy_class.new(
          PermissionProbe.new(allowed_code: "unrelated.#{suffix}"), PermissiveRecord.new
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

  test "admin and fisherman manifest access dispatches through the same action" do
    permission = create(:permission, code: "manifests.list")
    company = create(:company_profile)
    officer = build(:user, role: create(:role, permissions: [permission]))
    fisherman = build(:user, role: create(:role, :fisherman, company_profile: company, permissions: [permission]))

    assert_equal [true, true], [ManifestPolicy.new(officer, Manifest).index?,
                                ManifestPolicy.new(fisherman, Manifest).index?]
  end

  test "policy and controller sources contain no audience-specific policy actions or legacy fallbacks" do
    sources = Rails.root.glob("app/{policies,controllers}/**/*.rb").index_with(&:read)

    sources.each do |path, source|
      assert_no_match(/def fisherman_[a-z_]*\?/, source, path.to_s)
      assert_no_match(/authorize .*:fisherman_[a-z_]*\?/, source, path.to_s)
      assert_no_match(/def fisherman_(?:manifest|lookup|vessel)_[a-z_]*\?/, source, path.to_s)
    end
  end

  private

  def expected_resource(policy_class, action)
    return ManifestPolicy::APPROVALS if policy_class == ManifestPolicy && action.to_s.match?(/approve|amendment/)
    if policy_class == CaptureReportPolicy && action.to_s.match?(/verify|amendment/)
      return CaptureReportPolicy::VERIFICATIONS
    end

    policy_class::RESOURCE
  end
end
