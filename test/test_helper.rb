ENV["RAILS_ENV"] ||= "test"
# Keep tests independent of the developer's .env; mock tests enable the route explicitly.
ENV["BRUNEIID_MOCK_ENABLED"] = "false"
# Likewise for Active Directory: staff always sign in through the (mock) directory with this fake shared password.
ENV["AD_MODE"] = "mock"
ENV["AD_MOCK_PASSWORD"] = "mock-ad-password"
ENV["DEPLOY_ENV"] = "test"
require_relative "../config/environment"
# The Rails test command may load application.rb before this helper sets ENV.
Rails.configuration.x.brunei_id_mock_enabled = false
# Same reason: the config may already have been read at boot, before the ENV above was set.
Authentication::DirectoryConfig.instance_variable_set(:@current, Authentication::DirectoryConfig.load)
Rails.application.reload_routes!
require "rails/test_help"
require_relative "support/postgresql_number_triggers"
require_relative "support/brunei_id_callback_helper"
require_relative "support/directory_test_support"
require_relative "support/directory_accounts_support"
require_relative "support/rocbn_test_support"

# Rails' Ruby schema dump does not retain PostgreSQL functions/triggers. Install the two
# database-backed number generators after a fresh test schema load, before parallel workers fork.
PostgreSqlNumberTriggers.install!

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Each parallel worker uses its own test database. The Ruby schema dump does
    # not include PostgreSQL trigger functions, so install the generators again
    # after Rails connects a worker to its database.
    parallelize_setup do |_worker|
      PostgreSqlNumberTriggers.install!
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # The ROCBN registry is a second, MySQL database. Only tests that include RocbnTestSupport use it (and opt
    # back in to a transaction there), so every other test stays independent of that MySQL being up.
    skip_transactional_tests_for_database(:rocbn)

    # An officer-platform user whose role holds exactly one permission — a notification recipient that is only
    # reachable through that code.
    def create_admin_recipient(permission_code)
      permission = create(:permission, code: permission_code)
      create(:user, role: create(:role, permissions: [permission]))
    end

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include BruneiIdCallbackHelper

  # Staff have no DoFi password and sign in with the shared mock-directory password; everyone else with `password`.
  def auth_headers_for(user, password:)
    password = DirectoryTestSupport::MOCK_PASSWORD if user.directory_managed?
    post "/api/v1/auth/sign_in", params: { user: { username: user.username, password: password } }, as: :json
    { "Authorization" => response.headers["Authorization"] }
  end

  # Shared setup for the admin/fisherman manifest sub-resource controller tests (capture_reports,
  # expenses, minor_fishermen, fish_capture_details, fishing_gear_details) — both platforms' test
  # suites for the same resource need a role with the right permissions and a signed-in user,
  # which was previously copy-pasted per test file. See test/controllers/api/v1/{admin,fisherman}/
  # manifests/ for usage.
  MANIFEST_SUB_RESOURCE_TEST_PASSWORD = "Password123!".freeze

  def find_or_create_permissions(codes)
    codes.map { |code| Permission.find_or_create_by!(code: code) { |p| p.name = code } }
  end

  def create_role_with_permissions(kind:, permission_codes:, name: nil)
    create(:role, kind: kind, name: name || kind, permissions: find_or_create_permissions(permission_codes))
  end

  def fisherman_headers_for(manifest, permission_codes:)
    role = create(:role, :fisherman, company_profile: manifest.company_profile,
                                     permissions: find_or_create_permissions(permission_codes))
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
