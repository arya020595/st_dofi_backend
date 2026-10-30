require "test_helper"
require "open3"

# Talks to a real (in-process) TLS server, so it proves what the option-recording tests cannot: that the certificate
# chain and host name are actually enforced, that the system trust store is what is used when AD_CA_FILE is unset, and
# that a bind over verified TLS works end to end.
class Authentication::LdapAuthenticatorTlsTest < ActiveSupport::TestCase
  include DirectoryTestSupport
  include TestCertificates

  setup do
    @ca_key, @ca = issue_certificate("CN=Test AD CA", authority: true)
    @tmp = Dir.mktmpdir
    @ca_file = write_pem(@tmp, "ca.pem", @ca)
    @log = []
  end

  teardown do
    @directory&.close
    FileUtils.remove_entry(@tmp)
  end

  test "binds over TLS when the certificate is signed by the configured CA and names the host" do
    start_directory(dns: "localhost")

    assert_equal Success(:authenticated), authenticator.call(username: "ahmad", password: "right")
    assert_equal Failure(:invalid_credentials), authenticator.call(username: "ahmad", password: "wrong")
  end

  test "refuses a certificate that was not issued by the configured CA" do
    other_ca_file = write_pem(@tmp, "other-ca.pem", issue_certificate("CN=Someone Else", authority: true).last)
    start_directory(dns: "localhost")

    assert_refused authenticator(ca_file: other_ca_file), "untrusted_certificate"
  end

  test "refuses a certificate that does not name the host" do
    start_directory(dns: "another-host.example")

    assert_refused authenticator, "hostname_mismatch"
  end

  test "refuses an expired certificate" do
    start_directory(dns: "localhost", expired: true)

    assert_refused authenticator, "certificate_expired"
  end

  test "without AD_CA_FILE a certificate the system store does not trust is refused" do
    start_directory(dns: "localhost")

    assert_refused authenticator(ca_file: nil), "untrusted_certificate"
  end

  test "a blank AD_CA_FILE is the same as none" do
    start_directory(dns: "localhost")

    assert_nil directory_config(ad_ca_file: "  ").ca_file
    assert_refused authenticator(ca_file: "  "), "untrusted_certificate"
  end

  # The system trust store is OpenSSL's default one, which SSL_CERT_FILE points elsewhere. A child process gets its own
  # store from it, so nothing global changes in this one.
  test "without AD_CA_FILE the system trust store decides, in a process whose store holds this CA" do
    start_directory(dns: "localhost")
    other_ca_file = write_pem(@tmp, "other-ca.pem", issue_certificate("CN=Someone Else", authority: true).last)

    assert_equal "Success(:authenticated)", bind_in_child_process(trust_store: @ca_file)
    assert_equal "Failure(:directory_unavailable)", bind_in_child_process(trust_store: other_ca_file)
  end

  test "an AD_CA_FILE that holds no certificate is refused without connecting or using the system store" do
    start_directory(dns: "localhost")
    empty = File.join(@tmp, "empty.pem").tap { File.write(it, "") }
    garbage = File.join(@tmp, "garbage.pem").tap { File.write(it, "not a certificate") }

    results = [empty, garbage, @tmp].map { authenticator(ca_file: it).call(username: "ahmad", password: "right") }

    assert_equal [Failure(:directory_unavailable)], results.uniq
    assert_equal [0, ["misconfigured"] * 3], [@directory.accepted, @log.map { it.dig(:params, :reason) }]
  end

  test "a wrong password is tried once, not replayed on the other hosts" do
    start_directory(dns: "localhost")

    result = authenticator(host: "localhost,localhost,localhost").call(username: "ahmad", password: "wrong")

    assert_equal [Failure(:invalid_credentials), ["wrong"]], [result, @directory.binds]
  end

  private

  def authenticator(ca_file: @ca_file, host: "localhost")
    config = directory_config(ad_host: host, ad_port: @directory.port.to_s, ad_ca_file: ca_file)
    Authentication::LdapAuthenticator.new(config:, logger: ->(**entry) { @log << entry })
  end

  # The refusal is a 503-class result whose log names only the category of the TLS failure: no password, address or
  # OpenSSL text.
  def assert_refused(authenticator, category)
    result = authenticator.call(username: "ahmad", password: "right")

    assert_equal Failure(:directory_unavailable), result
    assert_equal([category], @log.map { it.dig(:params, :tls) })
    assert_empty @log.flat_map { it[:params].values }.grep(/right|127\.0\.0\.1|certificate verify/i)
  end

  # Runs the real LdapAuthenticator in a fresh Rails process, with `trust_store` as the system CA bundle and no
  # AD_CA_FILE, and returns what it answered.
  def bind_in_child_process(trust_store:)
    env = { "AD_MODE" => "ldap", "DEPLOY_ENV" => "test", "AD_HOST" => "localhost", "AD_PORT" => @directory.port.to_s,
            "AD_NETBIOS_DOMAIN" => "MPRT", "AD_CA_FILE" => nil, "SSL_CERT_FILE" => trust_store }
    script = 'puts Authentication::LdapAuthenticator.call(username: "ahmad", password: "right").inspect'
    output, status = Open3.capture2(env, RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", script,
                                    chdir: Rails.root.to_s)

    assert_predicate status, :success?
    output.lines.last.strip
  end

  def start_directory(dns:, expired: false)
    key, cert = issue_certificate("CN=#{dns}", host: dns, issuer: [@ca_key, @ca], expired:)
    @directory = TlsDirectory.new(key:, cert:)
  end
end
