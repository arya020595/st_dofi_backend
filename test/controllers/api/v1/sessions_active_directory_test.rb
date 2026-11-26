require "test_helper"

module Api
  module V1
    # POST /api/v1/auth/sign_in when staff are authenticated by Active Directory: what a successful sign-in looks like.
    class SessionsActiveDirectoryTest < ActionDispatch::IntegrationTest
      include DirectoryTestSupport
      include DirectoryAccountsSupport

      setup { create_directory_accounts }

      test "staff sign in with their directory password under any spelling of the username" do
        with_directory_config(mock_directory_config) do
          ["azri.nizam", "Azri.Nizam", "MPRT/Azri.Nizam", "mprt\\azri.nizam"].each do |typed|
            sign_in_as(typed, MOCK_PASSWORD)

            assert_response :ok, typed
            assert_equal @staff.id, response.parsed_body.dig("data", "user", "id"), typed
          end
        end
      end

      test "the response is the existing one: JWT header, access token and realtime token" do
        with_directory_config(mock_directory_config) do
          sign_in_as("azri.nizam", MOCK_PASSWORD)
          data = response.parsed_body["data"]

          assert_equal "Bearer #{data['access_token']}", response.headers["Authorization"]
          assert_predicate data["realtime_token"], :present?
        end
      end

      test "the issued token works, and signing out still revokes it" do
        with_directory_config(mock_directory_config) do
          sign_in_as("azri.nizam", MOCK_PASSWORD)
          headers = { "Authorization" => response.headers["Authorization"] }
          get("/api/v1/auth/me", headers:)

          assert_equal ["manifests.view"], response.parsed_body.dig("data", "permissions").pluck("code")

          delete("/api/v1/auth/sign_out", headers:)
          get("/api/v1/auth/me", headers:)

          assert_response :unauthorized
        end
      end

      test "a real-directory success signs the staff user in without any local password" do
        with_directory_config(directory_config) do
          with_ldap_result(Success(:authenticated)) do
            sign_in_as("azri.nizam", "whatever-the-directory-accepts")

            assert_response :ok
          end
        end
      end
    end
  end
end
