require "test_helper"

class Authentication::OfficerLoginTest < ActiveSupport::TestCase
  include DirectoryTestSupport

  setup do
    @officer_role = create(:role, kind: Role::DOFI_OFFICER)
    @custom_role = create(:role, name: "Inspector")
    @calls = []
    @entries = []
    @directory = lambda do |username:, password:|
      @calls << [username, password]
      password == "right" ? Success(:authenticated) : Failure(:invalid_credentials)
    end
  end

  def staff(username: "mprt/azri.nizam", role: @officer_role, **attributes)
    create(:user, :officer_shaped, role:, username:, **attributes)
  end

  def login(username, password = "right", authenticator: @directory, config: mock_directory_config)
    Authentication::OfficerLogin.new(config:, authenticator:, logger: ->(**entry) { @entries << entry })
                                .call(username:, password:)
  end

  test "authenticates a staff user however the username is written, binding with the stored short name" do
    user = staff

    ["azri.nizam", "Azri.Nizam", "MPRT/Azri.Nizam", "mprt\\azri.nizam", "  AZRI.NIZAM "].each do |typed|
      assert_equal Success(user), login(typed), typed
    end

    assert_equal [["azri.nizam", "right"]] * 5, @calls
  end

  test "a staff user stored without the domain prefix is found by either spelling" do
    user = staff(username: "azri.nizam")

    assert_equal Success(user), login("MPRT/azri.nizam")
    assert_equal Success(user), login("azri.nizam")
  end

  test "custom DoFi roles (no kind) are staff too" do
    user = staff(role: @custom_role)

    assert_equal Success(user), login("azri.nizam")
  end

  test "the directory's refusal and outage are passed through" do
    staff

    assert_equal Failure(:invalid_credentials), login("azri.nizam", "wrong")
    assert_equal Failure(:directory_unavailable),
                 login("azri.nizam", authenticator: ->(**) { Failure(:directory_unavailable) })
  end

  test "accounts that are not staff are not ours to decide and never reach the directory" do
    jetty_role = create(:role, kind: Role::JETTY_MANAGER)
    create(:user, :jetty_manager_shaped, role: jetty_role, username: "mprt/jetty.manager")
    create(:user, :fins_governed_fisherman, username: "mprt/fisherman.one")
    create(:user, role: nil, username: "mprt/no.role")

    %w[jetty.manager fisherman.one no.role nobody].each do |typed|
      assert_equal Failure(:not_applicable), login(typed), typed
    end
    assert_empty @calls
    assert_empty @entries
  end

  test "ineligible staff are refused without asking the directory" do
    staff(username: "mprt/discarded").discard
    staff(username: "mprt/inactive", status: "inactive")
    staff(username: "mprt/suspended", status: "suspended")

    %w[discarded inactive suspended].each do |typed|
      assert_equal Failure(:invalid_credentials), login(typed), typed
    end
    assert_empty @calls
    assert_equal(["ineligible_account"] * 3, @entries.map { it.dig(:params, :reason) })
  end

  test "an ambiguous username is refused rather than guessed" do
    staff(username: "azri.nizam")
    staff(username: "mprt/azri.nizam", role: @custom_role)

    assert_equal Failure(:invalid_credentials), login("azri.nizam")
    assert_empty @calls
    assert_equal "ambiguous_username", @entries.sole.dig(:params, :reason)
  end

  test "a stored username that is not a valid AD name is refused without asking the directory" do
    staff(username: "mprt/azri nizam")

    assert_equal Failure(:invalid_credentials), login("mprt/azri nizam")
    assert_empty @calls
  end

  test "logs who was refused or admitted, and why" do
    user = staff
    login("azri.nizam", "right")
    login("azri.nizam", "wrong")

    assert_equal [user.id, user.id], @entries.pluck(:user_id)
    assert_equal([%w[success], %w[failure]], @entries.map { |entry| [entry.dig(:params, :outcome)] })
    assert_equal([nil, :invalid_credentials], @entries.map { |entry| entry.dig(:params, :reason) })
  end

  test "never logs the password" do
    staff
    login("azri.nizam", "right")
    login("azri.nizam", "wrong")

    assert_no_match(/right|wrong/, @entries.to_s)
  end

  test "uses the mock directory in mock mode and the LDAP one otherwise" do
    user = staff
    login = Authentication::OfficerLogin.new(config: mock_directory_config, logger: ->(**) {})

    assert_equal Failure(:invalid_credentials), login.call(username: "azri.nizam", password: "nope")
    assert_equal Success(user), login.call(username: "azri.nizam", password: MOCK_PASSWORD)

    ldap_config = directory_config(ad_host: "")
    result = Authentication::OfficerLogin.new(config: ldap_config, logger: ->(**) {})
                                         .call(username: "azri.nizam", password: "x")

    assert_equal Failure(:directory_unavailable), result
  end
end
