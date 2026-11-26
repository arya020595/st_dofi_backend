require "test_helper"
require_relative "../../support/fake_ldap"

# What LdapAuthenticator asks of TLS, and how it reports a refused certificate, without any server: the options handed
# to net-ldap, and the log line for the failures net-ldap raises. The real handshakes are in
# ldap_authenticator_tls_test.rb.
class Authentication::LdapAuthenticatorTlsOptionsTest < ActiveSupport::TestCase
  include DirectoryTestSupport
  include TestCertificates

  def tls_options(config)
    ldap_class = FakeLdap.answering
    Authentication::LdapAuthenticator.new(config:, ldap_class:, logger: ->(**) {})
                                     .call(username: "ahmad", password: FakeLdap::RIGHT_PASSWORD)
    ldap_class.built.sole.dig(:encryption, :tls_options)
  end

  test "certificates are verified and TLS 1.2 or newer is demanded, with or without a CA file" do
    Dir.mktmpdir do |dir|
      ca_file = write_pem(dir, "ca.pem", issue_certificate("CN=Test AD CA", authority: true).last)
      [directory_config(ad_ca_file: ca_file), directory_config].each do |config|
        tls = tls_options(config)

        assert_equal [OpenSSL::SSL::VERIFY_PEER, OpenSSL::SSL::TLS1_2_VERSION],
                     tls.values_at(:verify_mode, :min_version)
      end
    end
  end

  test "an explicit CA file is passed on; without one the system store is left to OpenSSL" do
    Dir.mktmpdir do |dir|
      ca_file = write_pem(dir, "ca.pem", issue_certificate("CN=Test AD CA", authority: true).last)

      assert_equal ca_file, tls_options(directory_config(ad_ca_file: ca_file))[:ca_file]
      assert_empty tls_options(directory_config).keys & %i[ca_file ca_path cert_store]
    end
  end

  test "nothing in the application can turn certificate verification off" do
    sources = Rails.root.glob("{app,lib,config}/**/*.{rb,rake,yml}").reject { it.to_s.end_with?("_test.rb") }
    bypass = /VERIFY_NONE|verify_certificates|verify_hostname\s*[:=]+>?\s*false/
    offenders = sources.select { |file| File.foreach(file, encoding: "UTF-8", invalid: :replace).any?(bypass) }

    assert_empty offenders
  end

  test "a TLS failure wrapped by net-ldap is named by category, for one host or several, never by its raw text" do
    {
      "SSL_connect returned=1 errno=0 peeraddr=10.1.2.3:3269 state=error: certificate verify failed " \
      "(unable to get local issuer certificate)" => "untrusted_certificate",
      "SSL_connect returned=1 errno=0 state=error: certificate verify failed (certificate has expired)" =>
        "certificate_expired",
      "SSL_connect returned=1 errno=0 state=error: certificate verify failed (something new)" =>
        "certificate_rejected",
      "Connection refused - connect(2) for \"ad1.mprt.test\" port 3269" => nil
    }.each do |text, category|
      single = Net::LDAP::ConnectionError.new([[OpenSSL::SSL::SSLError.new(text), "ad1.mprt.test", 3269]])
      several = Net::LDAP::ConnectionError.new([[Errno::ECONNREFUSED.new, "ad1.mprt.test", 3269],
                                                [OpenSSL::SSL::SSLError.new(text), "ad2.mprt.test", 3269]])

      [single, several].each do |error|
        entries = log_for(error)

        assert_equal [category], entries.map { it.dig(:params, :tls) }, error.class.name
        assert_not_includes entries.to_s, "10.1.2.3"
      end
    end
  end

  private

  def log_for(error)
    entries = []
    logger = ->(**entry) { entries << entry }
    ldap_class = FakeLdap.answering(->(_) { error })
    Authentication::LdapAuthenticator.new(config: directory_config, ldap_class:, logger:)
                                     .call(username: "ahmad", password: "right")
    entries
  end
end
