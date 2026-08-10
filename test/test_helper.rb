ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# A minimal test double for an Active Storage service, standing in for the real minio_public /
# minio_assets_public S3 services in tests — those would otherwise try to sign against test env's
# blank credentials, which triggers a slow AWS credential-chain fallback (a real network call to
# the EC2 instance-metadata endpoint) before failing outright. Minitest::Mock isn't available in
# this Minitest version (removed from core in 6.x), hence hand-rolled rather than a gem.
class RecordingServiceDouble
  attr_reader :captured_key, :captured_options

  def initialize(return_url) = @return_url = return_url

  def url(key, **options)
    @captured_key = key
    @captured_options = options
    @return_url
  end
end

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Temporarily makes ActiveStorage::Blob.services.fetch(name) return fake_service instead of
    # looking up the real configured service — see RecordingServiceDouble above.
    def stub_fetched_service(name, fake_service)
      services = ActiveStorage::Blob.services
      original = services.method(:fetch)
      services.define_singleton_method(:fetch) do |requested|
        requested == name ? fake_service : original.call(requested)
      end
      yield
    ensure
      services.singleton_class.send(:remove_method, :fetch)
    end

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  def auth_headers_for(user, password:)
    post "/api/v1/auth/sign_in", params: { user: { username: user.username, password: password } }, as: :json
    { "Authorization" => response.headers["Authorization"] }
  end

  # Shared setup for the admin/fisherman manifest sub-resource controller tests (capture_reports,
  # expenses, minor_fishermen, fish_capture_details, fishing_gear_details) — both platforms' test
  # suites for the same resource need a role with the right permissions and a signed-in user,
  # which was previously copy-pasted per test file. See test/controllers/api/v1/{admin,fisherman}/
  # manifests/ for usage.
  MANIFEST_SUB_RESOURCE_TEST_PASSWORD = "Password123!".freeze

  def create_role_with_permissions(kind:, permission_codes:, name: nil)
    permissions = permission_codes.map { |code| Permission.find_or_create_by!(code: code) { |p| p.name = code } }
    role = Role.find_or_initialize_by(kind: kind)
    role.name = name || role.name || "#{kind.to_s.humanize} Role"
    role.description ||= "A test role"
    role.save! if role.new_record? || role.changed?
    role.permissions = permissions
    role
  end

  def fisherman_headers_for(manifest, permission_codes:)
    role = create_role_with_permissions(kind: Role::FISHERMAN, permission_codes: permission_codes)
    user = create(:user, role: role, company_profile: manifest.company_profile, ic_number: SecureRandom.hex(5),
                         registration_type: "Commercial", password: MANIFEST_SUB_RESOURCE_TEST_PASSWORD,
                         password_confirmation: MANIFEST_SUB_RESOURCE_TEST_PASSWORD)
    auth_headers_for(user, password: MANIFEST_SUB_RESOURCE_TEST_PASSWORD)
  end

  def officer_headers_for(permission_codes:)
    role = create_role_with_permissions(kind: Role::DOFI_OFFICER, permission_codes: permission_codes,
                                        name: "DoFi Officer")
    user = create(:user, role: role, position: "Administrator", unit: "HQ", username: "officer_#{SecureRandom.hex(4)}",
                         password: MANIFEST_SUB_RESOURCE_TEST_PASSWORD,
                         password_confirmation: MANIFEST_SUB_RESOURCE_TEST_PASSWORD)
    auth_headers_for(user, password: MANIFEST_SUB_RESOURCE_TEST_PASSWORD)
  end
end
