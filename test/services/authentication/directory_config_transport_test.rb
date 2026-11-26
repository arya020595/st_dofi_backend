require "test_helper"

# AD_TRANSPORT: LDAPS by default; plain LDAP (no TLS) only when asked for by name, and only for the real directory.
class Authentication::DirectoryConfigTransportTest < ActiveSupport::TestCase
  include DirectoryTestSupport

  test "the transport is LDAPS unless AD_TRANSPORT=plain says otherwise" do
    assert_equal ["ldaps", false], [directory_config.transport, directory_config.plain_transport?]

    plain = directory_config(ad_transport: " Plain ", ad_port: "389")

    assert_predicate plain, :plain_transport?
    assert_empty plain.problems
  end

  test "plain only applies to the real directory, never to the mock" do
    assert_not_predicate mock_directory_config(ad_transport: "plain"), :plain_transport?
  end

  test "plaintext is reachable only through AD_TRANSPORT=plain, and plain is refused on TLS-only ports" do
    {
      { ad_transport: "none" } => /AD_TRANSPORT must be one of/,
      { ad_transport: "" } => /AD_TRANSPORT must be one of/,
      { ad_port: "389" } => /AD_TRANSPORT=plain/,
      { ad_transport: "plain", ad_port: "636" } => /only speaks TLS/,
      { ad_transport: "plain", ad_port: "3269" } => /only speaks TLS/,
      { ad_transport: "plain", ad_port: "389", ad_ca_file: OpenSSL::X509::DEFAULT_CERT_FILE } =>
        /AD_CA_FILE has no effect/
    }.each do |overrides, expected|
      assert_match(expected, directory_config(**overrides).problems.join("; "), "for #{overrides}")
    end
  end
end
