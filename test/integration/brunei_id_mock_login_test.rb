require "test_helper"

class BruneiIdMockLoginTest < ActionDispatch::IntegrationTest
  setup do
    @original_enabled = Rails.configuration.x.brunei_id_mock_enabled
    Rails.configuration.x.brunei_id_mock_enabled = true
    Rails.application.reload_routes!
  end

  teardown do
    Rails.configuration.x.brunei_id_mock_enabled = @original_enabled
    Rails.application.reload_routes!
    Current.reset
  end

  test "audience-scoped mock claims a fisherman and returns the original callback-shaped payload" do
    user = create(:user, :fins_governed_fisherman)

    mock_login(user.ic_number.delete("-"), audience: "fisherman")

    assert_response :ok
    assert_equal "active", user.reload.fisherman_status
    assert_predicate user, :claimed_at?
    assert_predicate user, :brunei_id_verified_at?
    assert_equal "dashboard", response.parsed_body.dig("data", "next_action")
    assert_equal({ "ic_number" => user.normalized_ic_number }, response.parsed_body.dig("data", "brunei_id_profile"))
    assert_equal({ "response_keys" => [] }, response.parsed_body.dig("data", "brunei_id_token_metadata"))
    assert_tokens(user)
  end

  test "audience-scoped mock authenticates an active jetty manager" do
    user = jetty_manager

    mock_login(user.ic_number, audience: "jetty_manager")

    assert_response :ok
    assert_equal "dashboard", response.parsed_body.dig("data", "next_action")
    assert_tokens(user)
  end

  test "mock audience lookup cannot authenticate the other audience" do
    users = { "jetty_manager" => create(:user, :fins_governed_fisherman), "fisherman" => jetty_manager }
    users.each do |audience, user|
      mock_login(user.ic_number, audience:)

      assert_response :not_found
      assert_equal "#{audience}_account_not_provisioned", response.parsed_body["code"]
      assert_nil response.headers["Authorization"]
    end
  end

  test "unknown mock identities keep the audience-specific not-provisioned response" do
    %w[fisherman jetty_manager].each do |audience|
      assert_no_difference("User.count") { mock_login("99-999999", audience:) }

      assert_response :not_found
      assert_equal "#{audience}_account_not_provisioned", response.parsed_body["code"]
      assert_equal "not_found", response.parsed_body.dig("data", "registration_status")
      assert_nil response.headers["Authorization"]
    end
  end

  test "inactive audience-scoped accounts keep their 422 response without tokens" do
    user = jetty_manager(status: "inactive")
    mock_login(user.ic_number, audience: "jetty_manager")

    assert_inactive_response("inactive")

    %w[suspended revoked].each do |status|
      user = create(:user, :fins_governed_fisherman, fisherman_status: status)
      mock_login(user.ic_number, audience: "fisherman")

      assert_inactive_response(status)
    end
  end

  test "missing audience keeps the original dashboard payload and claims a fisherman" do
    user = create(:user, :fins_governed_fisherman)

    mock_login(user.ic_number)

    assert_response :ok
    assert_equal "active", user.reload.fisherman_status
    assert_equal %w[access_token realtime_token realtime_token_expires_at user], response.parsed_body["data"].keys.sort
    assert_tokens(user)
  end

  test "unrecognized audience preserves the original unscoped developer lookup" do
    user = create(:user, :officer_shaped, ic_number: "91-654321", role: create(:role, kind: Role::DOFI_OFFICER))

    mock_login(user.ic_number, audience: "legacy-client")

    assert_response :ok
    assert_tokens(user)
  end

  test "unscoped inactive mock login keeps 200 and user data only" do
    user = jetty_manager(status: "inactive")

    mock_login(user.ic_number)

    assert_response :ok
    assert_equal({ "status" => "success", "data" => UserBlueprint.render_as_hash(user).as_json },
                 response.parsed_body)
    assert_nil response.headers["Authorization"]
  end

  test "unscoped missing identity keeps the translated 404 response" do
    mock_login("99-999999")

    assert_response :not_found
    assert_equal({ "status" => "fail", "message" => I18n.t("errors.account_not_found") }, response.parsed_body)
    assert_nil response.headers["Authorization"]
  end

  test "discarded accounts cannot authenticate through mock login" do
    user = jetty_manager
    user.discard!

    mock_login(user.ic_number)

    assert_response :not_found
    assert_nil response.headers["Authorization"]
  end

  test "missing and blank IC parameters keep the bad request response" do
    [nil, ""].each do |ic_number|
      post "/api/v1/auth/brunei_id", params: { ic_number: }, as: :json

      assert_response :bad_request
      assert_nil response.headers["Authorization"]
    end
  end

  test "disabled mock route returns 404 without claiming an account or issuing tokens" do
    Rails.configuration.x.brunei_id_mock_enabled = false
    Rails.application.reload_routes!
    user = create(:user, :fins_governed_fisherman)
    original_exceptions = Rails.application.env_config["action_dispatch.show_exceptions"]
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all

    mock_login(user.ic_number, audience: "fisherman")

    assert_response :not_found
    assert_equal ["claimable", nil, nil], [user.reload.fisherman_status, user.claimed_at, user.brunei_id_verified_at]
    assert_nil response.headers["Authorization"]
  ensure
    Rails.application.env_config["action_dispatch.show_exceptions"] = original_exceptions
  end

  test "enabling mock does not let invalid OIDC credentials authenticate by IC" do
    user = create(:user, :fins_governed_fisherman)
    with_brunei_id_result(-> { Failure(BruneiId::OidcCallback::INVALID_CODE_ERROR) }) do
      post "/api/v1/auth/brunei_id/callback", params: {
        audience: "fisherman", ic_number: user.ic_number, code: "bad-code", code_verifier: "verifier",
        nonce: "nonce", redirect_uri: "https://example.test/callback"
      }, as: :json
    end

    assert_response :unauthorized
    assert_equal "invalid_code", response.parsed_body["code"]
    assert_equal "claimable", user.reload.fisherman_status
    assert_nil response.headers["Authorization"]
  end

  private

  def mock_login(ic_number, audience: nil)
    with_brunei_id_result(-> { flunk "Mock login must not invoke OIDC" }) do
      post "/api/v1/auth/brunei_id", params: { ic_number:, audience: }.compact,
                                     headers: { "X-Request-Id" => "mock-login-request" }, as: :json
    end

    assert_empty Current.attributes.values.compact
  end

  def jetty_manager(**attributes)
    create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER), **attributes)
  end

  def assert_inactive_response(status)
    assert_response :unprocessable_content
    assert_equal "inactive_registration", response.parsed_body["code"]
    assert_equal status, response.parsed_body.dig("data", "registration_status")
    assert_nil response.headers["Authorization"]
    assert_nil response.parsed_body.dig("data", "access_token")
  end

  def assert_tokens(user)
    data = response.parsed_body.fetch("data")

    assert_equal "Bearer #{data.fetch('access_token')}", response.headers["Authorization"]
    assert_equal user, Realtime::CableToken.user_for(data.fetch("realtime_token"))
    assert_predicate Time.iso8601(data.fetch("realtime_token_expires_at")), :future?
    assert_jwt_session(user, data.fetch("access_token"))
  end

  def assert_jwt_session(user, token)
    get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :ok
    assert_equal user.id, response.parsed_body.dig("data", "user", "id")
  end
end
