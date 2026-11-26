require "test_helper"

module ActiveDirectory
  # After a real LDAPS sign-in: the JWT lifecycle (JTIMatcher), what the local database lets the officer do, and the
  # sign-in flows that must not notice the directory at all.
  class SessionAndAccessTest < ActionDispatch::IntegrationTest
    include ActiveDirectoryE2eSupport

    setup { start_directory }

    def statuses(headers)
      ["/api/v1/auth/me", "/api/v1/permissions"].map do |path|
        get(path, headers:)
        response.status
      end
    end

    # --- I. JWT lifecycle -------------------------------------------------------------------------------------

    test "the token works, sign-out revokes it, and a new sign-in is a new bind" do
      with_ad do
        old = signed_in_headers("azri.nizam")

        assert_equal [200, 200], statuses(old)
        delete "/api/v1/auth/sign_out", headers: old

        assert_response :success
        assert_equal [401, 401], statuses(old)
        fresh = signed_in_headers("azri.nizam")

        assert_equal [[200, 200], [401, 401]], [statuses(fresh), statuses(old)]
      end

      assert_equal [PASSWORD, PASSWORD], @directory.binds
    end

    test "losing access revokes the token for good: re-enabling does not revive it, a new directory sign-in works" do
      events = { "deactivated" => %i[deactivate! reactivate!], "suspended" => %i[suspend! reactivate!] }

      with_ad do
        events.each do |label, (remove, restore)|
          old = signed_in_headers("azri.nizam")
          @staff.public_send(remove)

          assert_equal [401, 401], statuses(old), label
          @staff.public_send(restore)

          assert_equal [401, 401], statuses(old), "#{label}, then re-enabled"
          assert_equal [200, 200], statuses(signed_in_headers("azri.nizam")), label
        end
      end
    end

    test "a discarded officer's token dies and stays dead after undiscard" do
      with_ad do
        old = signed_in_headers("azri.nizam")
        @staff.discard

        assert_equal [401, 401], statuses(old)
        @staff.undiscard

        assert_equal [401, 401], statuses(old)
        assert_equal [200, 200], statuses(signed_in_headers("azri.nizam"))
      end
    end

    test "changing the directory username revokes the token; the new name signs in, the old one no longer does" do
      with_ad do
        old = signed_in_headers("azri.nizam")
        @staff.update!(username: "mprt/new.name")

        assert_equal [401, 401], statuses(old)
        assert_equal [200, 401], [ad_sign_in("new.name"), ad_sign_in("azri.nizam")]
      end
    end

    test "ordinary profile changes keep the token" do
      with_ad do
        headers = signed_in_headers("azri.nizam")
        @staff.update!(name: "Renamed", position: "Inspector", unit: "Block B", preferred_locale: "ms")

        assert_equal [200, 200], statuses(headers)
      end
    end

    # --- J. authorization comes from PostgreSQL ---------------------------------------------------------------

    test "the officer's permissions are the local role's: the directory supplies none, and a grant applies at once" do
      with_ad do
        headers = signed_in_headers("azri.nizam")
        get "/api/v1/auth/me", headers: headers

        assert_equal ["manifests.view"], response.parsed_body.dig("data", "permissions").pluck("code")
        get "/api/v1/admin/users", headers: headers

        assert_response :forbidden
        @staff.role.permissions << create(:permission, code: "users.list", name: "Users - List")
        get "/api/v1/admin/users", headers: headers

        assert_response :success
      end
    end

    # --- K. other sign-in flows --------------------------------------------------------------------------------

    test "Jetty Managers and Fishermen sign in as before and never touch the directory" do
      with_ad do
        assert_equal [200, 200], [sign_in_as(@jetty.username, LOCAL_PASSWORD),
                                  sign_in_as(@fisherman.username, LOCAL_PASSWORD)]
        assert_equal [401, 401], [sign_in_as(@jetty.username, PASSWORD), sign_in_as(@fisherman.username, PASSWORD)]
      end

      assert_equal 0, @directory.accepted
    end

    test "the mock directory still works where it is configured (local, staging)" do
      with_directory_config(mock_directory_config) do
        assert_equal [200, 401], [ad_sign_in("azri.nizam", MOCK_PASSWORD), ad_sign_in("azri.nizam", PASSWORD)]
      end

      assert_equal 0, @directory.accepted
    end
  end
end
