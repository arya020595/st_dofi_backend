require "test_helper"

module Api
  module V1
    # AD_MODE=mock (local, staging): every staff user has their own username and shares the one AD_MOCK_PASSWORD from
    # the environment. This runs against the real configuration that test_helper loads from ENV.
    class SessionsSharedMockPasswordTest < ActionDispatch::IntegrationTest
      include DirectoryAccountsSupport

      MOCK = DirectoryTestSupport::MOCK_PASSWORD

      setup do
        create_directory_accounts
        custom_role = create(:role, name: "Inspector")
        @custom = create(:user, role: custom_role, username: "mprt/custom.inspector")
        @another = create(:user, :officer_shaped, role: @staff.role, username: "mprt/another.officer")
      end

      test "different DoFi Officers, including a custom DoFi role, all sign in with the same mock password" do
        signed_in = [@staff, @another, @custom].map do |user|
          sign_in_as(user.username, MOCK)
          [response.status, response.parsed_body.dig("data", "user", "id")]
        end

        assert_equal [[200, @staff.id], [200, @another.id], [200, @custom.id]], signed_in
      end

      test "the short name and the prefixed name reach the same officer" do
        sign_in_as("another.officer", MOCK)

        assert_equal @another.id, response.parsed_body.dig("data", "user", "id")
      end

      test "a wrong or blank password is refused for an existing officer" do
        statuses = ["wrong", "", "mock-ad-passwor", "#{MOCK} "].map { |password| sign_in_as(@staff.username, password) }

        assert_equal [401] * 4, statuses
      end

      test "the mock password does not admit unknown, inactive, suspended or discarded users" do
        create(:user, :officer_shaped, role: @staff.role, username: "mprt/inactive.one", status: "inactive")
        create(:user, :officer_shaped, role: @staff.role, username: "mprt/suspended.one", status: "suspended")
        create(:user, :officer_shaped, role: @staff.role, username: "mprt/discarded.one").discard
        statuses = %w[nobody.here inactive.one suspended.one discarded.one].map { |name| sign_in_as(name, MOCK) }

        assert_equal [401] * 4, statuses
      end

      test "the mock password is not a password for Jetty Managers or Fishermen, who stay on their own sign-in" do
        assert_equal [401, 401], [sign_in_as(@jetty.username, MOCK), sign_in_as(@fisherman.username, MOCK)]
        assert_equal [200, 200],
                     [sign_in_as(@jetty.username, LOCAL_PASSWORD), sign_in_as(@fisherman.username, LOCAL_PASSWORD)]
      end

      test "the mock password is never stored as, or accepted as, a user's own password" do
        users = [@staff, @another, @custom]

        assert(users.none? { |user| BCrypt::Password.new(user.encrypted_password).is_password?(MOCK) })
        assert(users.none? { |user| user.valid_password?(MOCK) })
      end
    end
  end
end
