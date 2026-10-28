# Runs the real Rails app in AD_MODE=ldap against a TlsDirectory (a local LDAPS stand-in), so a test goes through
# POST /api/v1/auth/sign_in, the Warden strategy, OfficerLogin, the real LdapAuthenticator and net-ldap over TCP + TLS.
# Everything is temporary: certificates, accounts, the port. See test/integration/active_directory/.
module ActiveDirectoryE2eSupport
  extend ActiveSupport::Concern
  include DirectoryTestSupport
  include DirectoryAccountsSupport
  include TestCertificates

  PASSWORD = "Ad-Fixture-Pass-1".freeze # the simulator's password for its fixture accounts, nothing real

  included do
    setup do
      create_directory_accounts
      @ca_key, @ca = issue_certificate("CN=Test AD CA", authority: true)
      @tmp = Dir.mktmpdir
      @ca_file = write_pem(@tmp, "ca.pem", @ca)
    end

    teardown do
      @directory&.close
      FileUtils.remove_entry(@tmp)
    end
  end

  # Starts the simulator; `dns` is the name its certificate carries. Its fixture accounts are the staff users the tests
  # create, plus one the directory has but DoFi does not know, and one the directory has disabled.
  def start_directory(dns: "localhost", expired: false, accounts: nil, **)
    key, cert = issue_certificate("CN=#{dns}", host: dns, issuer: [@ca_key, @ca], expired:)
    wrong = issue_certificate("CN=localhost", host: "wrong-host.example", issuer: [@ca_key, @ca])
    @directory = TlsDirectory.new(key:, cert:, accounts: accounts || default_accounts, rejected: wrong, **)
  end

  def default_accounts
    enabled = %w[azri.nizam inactive.one suspended.one discarded.one new.name ghost.user].index_with { PASSWORD }
    enabled.merge("disabled.one" => { password: PASSWORD, enabled: false })
  end

  # The configuration the real service reads (AD_MODE=ldap), pointed at the simulator. Short timeouts keep the
  # unavailable and timeout cases quick.
  def ad_config(host: "localhost", ca_file: @ca_file, **overrides)
    directory_config(ad_host: host, ad_port: @directory.port.to_s, ad_ca_file: ca_file, ad_connect_timeout: "1",
                     ad_operation_timeout: "1", **overrides)
  end

  def with_ad(**overrides, &)
    with_directory_config(ad_config(**overrides), &)
  end

  def create_staff(username, **attributes)
    create(:user, :officer_shaped, role: @staff.role, username: "mprt/#{username}", **attributes)
  end

  # Signs in and returns the status; the token, when there is one, is read with `bearer`.
  def ad_sign_in(username, password = PASSWORD) = sign_in_as(username, password)

  def bearer = { "Authorization" => response.headers["Authorization"].to_s }

  def token_issued?
    response.headers["Authorization"].present? || response.parsed_body.dig("data", "access_token").present?
  end

  def signed_in_headers(username, password = PASSWORD)
    ad_sign_in(username, password)

    assert_response :success
    bearer
  end

  # Everything the app (and Rails' own request log) wrote while the block ran.
  def capture_logs
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    originals = [Rails.logger, ActionController::Base.logger, ActiveSupport::LogSubscriber.logger]
    Rails.logger = ActionController::Base.logger = ActiveSupport::LogSubscriber.logger = logger
    yield
    io.string
  ensure
    Rails.logger, ActionController::Base.logger, ActiveSupport::LogSubscriber.logger = originals
  end

  def logged_events(log)
    entries = log.lines.filter_map do |line|
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end
    entries.select { it.is_a?(Hash) && it["event"] }
  end
end
