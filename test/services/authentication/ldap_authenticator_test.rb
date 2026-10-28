require "test_helper"
require_relative "../../support/directory_authenticator_contract"
require_relative "../../support/fake_ldap"

class Authentication::LdapAuthenticatorTest < ActiveSupport::TestCase
  include DirectoryTestSupport
  include DirectoryAuthenticatorContract

  UNAVAILABLE_ERRORS = [
    Net::LDAP::ConnectionError.new([[Errno::ECONNREFUSED.new, "ad1.mprt.test", 3269]]),
    OpenSSL::SSL::SSLError.new("certificate verify failed"), Errno::ECONNREFUSED.new, SocketError.new,
    Timeout::Error.new
  ].freeze

  def build(config: directory_config, ldap_class: FakeLdap.answering, entries: [])
    Authentication::LdapAuthenticator.new(config:, ldap_class:, logger: ->(**entry) { entries << entry })
  end

  def authenticator = build
  def good_password = FakeLdap::RIGHT_PASSWORD
  def bad_password = "wrong"

  def bind_options(config: directory_config)
    ldap_class = FakeLdap.answering
    build(config:, ldap_class:).call(username: "ahmad", password: FakeLdap::RIGHT_PASSWORD)
    ldap_class.built.sole
  end

  test "dials every configured host over LDAPS with the configured connect timeout" do
    options = bind_options

    assert_equal [["ad1.mprt.test", 3269], ["ad2.mprt.test", 3269]], options[:hosts]
    assert_equal [3, :simple_tls], [options[:connect_timeout], options.dig(:encryption, :method)]
  end

  test "binds as DOMAIN\\name, or name@dns-domain with the UPN format" do
    assert_equal({ method: :simple, username: "MPRT\\ahmad", password: "right" }, bind_options[:auth])
    assert_equal "ahmad@MPRT.EG.GOV.BN",
                 bind_options(config: directory_config(ad_bind_format: "upn")).dig(:auth, :username)
  end

  test "TLS options verify the certificate and demand TLS 1.2 or newer" do
    tls = bind_options(config: directory_config(ad_ca_file: __FILE__)).dig(:encryption, :tls_options)

    assert_equal OpenSSL::SSL::VERIFY_PEER, tls[:verify_mode]
    assert_equal OpenSSL::SSL::TLS1_2_VERSION, tls[:min_version]
    assert_equal __FILE__, tls[:ca_file]
  end

  test "an unusable password or name never reaches the directory" do
    ldap_class = FakeLdap.answering
    unusable = [["ahmad", ""], ["ahmad", nil], ["ahmad", "a\0b"], ["ahmad", "x" * 257], ["a b", "right"],
                ["", "right"], ["MPRT\\ahmad", "right"]]
    results = unusable.map { |username, password| build(ldap_class:).call(username:, password:) }

    assert_equal [Failure(:invalid_credentials)], results.uniq
    assert_empty ldap_class.built
  end

  test "result codes other than invalid credentials mean the directory is unavailable" do
    [53, 51, 52, 1].each do |code|
      ldap_class = FakeLdap.answering(->(_) { code })

      assert_equal Failure(:directory_unavailable), build(ldap_class:).call(username: "ahmad", password: "right"), code
    end
  end

  test "connection, TLS and timeout errors mean the directory is unavailable" do
    UNAVAILABLE_ERRORS.each do |error|
      ldap_class = FakeLdap.answering(->(_) { error })

      assert_equal Failure(:directory_unavailable), build(ldap_class:).call(username: "ahmad", password: "right"),
                   error.class.name
    end
  end

  test "a misconfigured directory fails closed without opening a connection" do
    ldap_class = FakeLdap.answering
    result = build(config: directory_config(ad_host: ""), ldap_class:).call(username: "ahmad", password: "right")

    assert_equal Failure(:directory_unavailable), result
    assert_empty ldap_class.built
  end

  test "logs why the directory was unavailable without the password or the account" do
    entries = []
    ldap_class = FakeLdap.answering(->(_) { OpenSSL::SSL::SSLError.new("hostname mismatch for ahmad: hunter2") })
    build(ldap_class:, entries:).call(username: "ahmad", password: "hunter2")

    assert_equal [{ event: "ad.directory_unavailable", level: :error, params: { reason: "OpenSSL::SSL::SSLError" } }],
                 entries
  end
end
