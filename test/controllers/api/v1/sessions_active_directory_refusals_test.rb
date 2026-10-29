require "test_helper"

module Api
  module V1
    # POST /api/v1/auth/sign_in when staff are authenticated by Active Directory: refusals, and what must not change.
    class SessionsActiveDirectoryRefusalsTest < ActionDispatch::IntegrationTest
      include DirectoryTestSupport
      include DirectoryAccountsSupport

      setup { create_directory_accounts }

      test "a staff user's local password never signs them in" do
        [mock_directory_config, directory_config].each do |config|
          with_directory_config(config) do
            with_ldap_result(Failure(:invalid_credentials)) do
              ["azri.nizam", "AZRI.NIZAM", "mprt/azri.nizam", "MPRT\\azri.nizam", " azri.nizam "].each do |typed|
                sign_in_as(typed, LOCAL_PASSWORD)

                assert_response :unauthorized, "#{config.mode} #{typed}"
              end
            end
          end
        end
      end

      test "nor when the directory is down, which is a 503 rather than a fallback" do
        with_directory_config(directory_config) do
          with_ldap_result(Failure(:directory_unavailable)) do
            sign_in_as("azri.nizam", LOCAL_PASSWORD)

            assert_response :service_unavailable
            assert_equal({ "status" => "fail", "message" => I18n.t("errors.directory_unavailable") },
                         response.parsed_body)
          end
        end
      end

      test "the mock can simulate an unavailable directory" do
        with_directory_config(mock_directory_config) do
          sign_in_as("azri.nizam", Authentication::MockLdapAuthenticator::UNAVAILABLE_PASSWORD)

          assert_response :service_unavailable
        end
      end

      test "unknown user, wrong directory password and inactive staff are indistinguishable" do
        create(:user, :officer_shaped, role: @staff.role, username: "mprt/inactive.one", status: "inactive")
        attempts = [["nobody", "x"], ["azri.nizam", "wrong"], ["inactive.one", MOCK_PASSWORD]]
        bodies = with_directory_config(mock_directory_config) do
          attempts.map do |username, password|
            sign_in_as(username, password)
            [response.status, response.parsed_body]
          end
        end

        assert_equal [[401, bodies.first.last]] * 3, bodies
      end

      test "a discarded staff user cannot sign in" do
        @staff.discard
        with_directory_config(mock_directory_config) do
          sign_in_as("azri.nizam", MOCK_PASSWORD)

          assert_response :unauthorized
        end
      end

      test "Fisherman and Jetty Manager sign-in is unchanged and never touches the directory" do
        [mock_directory_config, directory_config].each do |config|
          with_directory_config(config) do
            with_ldap_result(Failure(:directory_unavailable)) do
              statuses = [@fisherman, @jetty].flat_map do |user|
                [sign_in_as(user.username, LOCAL_PASSWORD), sign_in_as(user.username, "wrong")]
              end

              assert_equal [200, 401, 200, 401], statuses, config.mode
            end
          end
        end
      end
    end
  end
end
