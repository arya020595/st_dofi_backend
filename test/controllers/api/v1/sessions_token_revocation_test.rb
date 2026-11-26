require "test_helper"

module Api
  module V1
    # An issued JWT stops working on sign-out and whenever its user loses access or changes sign-in identity, for
    # every kind of user, and never comes back when the account is re-enabled.
    class SessionsTokenRevocationTest < ActionDispatch::IntegrationTest
      include DirectoryAccountsSupport

      setup do
        create_directory_accounts
        @fisherman = create(:user, :fins_governed_fisherman, fisherman_status: "active", claimed_at: Time.current,
                                                             brunei_id_verified_at: Time.current,
                                                             password: LOCAL_PASSWORD)
      end

      def headers_for(user) = auth_headers_for(user, password: LOCAL_PASSWORD)

      # The statuses of a protected endpoint and of /auth/me, so a test covers more than one route.
      def statuses_with(headers)
        ["/api/v1/permissions", "/api/v1/auth/me"].map do |path|
          get(path, headers:)
          response.status
        end
      end

      def users = [@staff, @jetty, @fisherman]

      test "sign-out revokes the token on every protected endpoint, and a new sign-in works" do
        results = users.map do |user|
          old = headers_for(user)
          before = statuses_with(old)
          delete("/api/v1/auth/sign_out", headers: old)
          [before, response.status, statuses_with(old), statuses_with(headers_for(user)), statuses_with(old)]
        end

        assert_equal [[[200, 200], 200, [401, 401], [200, 200], [401, 401]]] * 3, results
      end

      test "sign-out rotates the JTI exactly once" do
        headers = headers_for(@staff)
        rotations = 0
        counter = ->(*, payload) { rotations += 1 if payload[:sql].match?(/UPDATE "users" SET "jti"/) }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          delete("/api/v1/auth/sign_out", headers:)
        end

        assert_equal 1, rotations
      end

      test "a user who loses access cannot keep using an earlier token, with the same body as any revoked token" do
        signed_out = headers_for(create(:user, :officer_shaped, role: @staff.role))
        delete("/api/v1/auth/sign_out", headers: signed_out)
        get("/api/v1/auth/me", headers: signed_out)
        generic = response.body
        {
          "deactivated staff" => [@staff, :deactivate!], "suspended staff" => [@staff, :suspend!],
          "deactivated Jetty Manager" => [@jetty, :deactivate!],
          "suspended Fisherman" => [@fisherman, :suspend_fisherman!],
          "revoked Fisherman" => [@fisherman, :revoke_fisherman!]
        }.each do |label, (user, event)|
          headers = headers_for(user)
          user.public_send(event)

          assert_equal [401, 401], statuses_with(headers), label
          assert_equal generic, response.body, label
          user.reload.update_columns(status: "active", fisherman_status: user.fisherman_status.presence && "active") # rubocop:disable Rails/SkipsModelValidations
        end
      end

      test "a direct status write and a discard also lock out a live token" do
        users.each do |user|
          headers = headers_for(user)
          user.update!(status: "inactive") unless user == @fisherman
          user.discard if user == @fisherman

          assert_equal [401, 401], statuses_with(headers), user.username
        end
        discarded = headers_for(create(:user, :officer_shaped, role: @staff.role))
        User.last.discard

        assert_equal [401, 401], statuses_with(discarded)
      end

      test "re-enabling an account does not revive tokens issued before, but a new sign-in works" do
        users.each do |user|
          old = headers_for(user)
          user.fisherman? ? user.suspend_fisherman! : user.deactivate!
          user.fisherman? ? user.reactivate_fisherman! : user.reactivate!

          assert_equal [401, 401], statuses_with(old), user.username
          assert_equal [200, 200], statuses_with(headers_for(user)), user.username
        end
      end

      test "undiscarding does not revive a token issued before the discard" do
        old = headers_for(@staff)
        @staff.discard
        @staff.undiscard

        assert_equal [401, 401], statuses_with(old)
        assert_equal [200, 200], statuses_with(headers_for(@staff))
      end

      test "changing a username revokes the token; the new name signs in and the old one does not" do
        old = headers_for(@staff)
        @staff.update!(username: "mprt/new.name")

        assert_equal [401, 401], statuses_with(old)
        assert_equal 200, sign_in_as("new.name", DirectoryTestSupport::MOCK_PASSWORD)
        assert_equal 401, sign_in_as("azri.nizam", DirectoryTestSupport::MOCK_PASSWORD)
      end

      test "ordinary profile changes keep the token working" do
        headers = headers_for(@staff)
        @staff.update!(name: "Renamed", position: "Inspector", unit: "Block B", contact_no: "+6738123456",
                       email: "renamed@example.test", preferred_locale: "ms")
        patch("/api/v1/profile/locale", params: { locale: "en" }, headers:, as: :json)

        assert_response :success
        assert_equal [200, 200], statuses_with(headers)
      end
    end
  end
end
