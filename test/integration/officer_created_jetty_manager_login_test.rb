require "test_helper"

# Jetty Managers are created only by a DoFi Officer (User Management → External Users) and can then log
# in via BruneiID straight away — no registration or FINS approval step in between. Deactivating the
# account blocks the next BruneiID login; reactivating it restores access.
class OfficerCreatedJettyManagerLoginTest < ActionDispatch::IntegrationTest
  IC_NUMBER = "01-424242".freeze

  setup do
    create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
    @officer_headers = officer_headers_for(permission_codes: %w[
                                             external_users.create external_users.deactivate
                                             external_users.reactivate
                                           ])
  end

  test "an officer-created jetty manager logs in via BruneiID until deactivated" do
    # 1. Officer creates the Jetty Manager — active immediately.
    post "/api/v1/admin/external_users/jetty_managers",
         params: { jetty_manager: { name: "Ahmad Firdaus", ic_number: IC_NUMBER, unit: "Docks",
                                    position: "Jetty Manager" } },
         headers: @officer_headers, as: :json

    assert_response :created
    jetty_manager_id = response.parsed_body.dig("data", "id")

    # 2. The Jetty Manager logs in via BruneiID (IC typed without the dash) and gets a working token.
    brunei_id_login("01424242")

    assert_response :ok
    assert_equal "dashboard", response.parsed_body.dig("data", "next_action")

    get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{response.parsed_body.dig('data', 'access_token')}" }

    assert_response :ok

    # 3. Officer deactivates the account — the next BruneiID login is refused.
    post "/api/v1/admin/external_users/jetty_managers/#{jetty_manager_id}/deactivate", headers: @officer_headers

    assert_response :ok
    brunei_id_login(IC_NUMBER)

    assert_response :unauthorized
    assert_equal "Account is inactive or unavailable.", response.parsed_body["message"]

    # 4. Officer reactivates — login works again.
    post "/api/v1/admin/external_users/jetty_managers/#{jetty_manager_id}/reactivate", headers: @officer_headers

    assert_response :ok
    brunei_id_login(IC_NUMBER)

    assert_response :ok
    assert_equal "dashboard", response.parsed_body.dig("data", "next_action")
  end

  private

  def brunei_id_login(ic_number)
    post "/api/v1/auth/brunei_id", params: { ic_number: ic_number, audience: "jetty_manager" }, as: :json
  end
end
