require "test_helper"

# AD_TRANSPORT=plain (the client's choice, matching their other AD integrations): a real plaintext LDAP server, so it
# proves the bind works without TLS, and that plaintext is only ever the explicit choice, never a fallback.
class Authentication::LdapAuthenticatorPlainTest < ActiveSupport::TestCase
  include DirectoryTestSupport

  setup { @log = [] }
  teardown { @directory&.close }

  test "binds over plain LDAP with the netbios identity when AD_TRANSPORT=plain" do
    @directory = PlainDirectory.new(accounts: { "ahmad" => "secret" })

    assert_equal Success(:authenticated), plain_authenticator.call(username: "ahmad", password: "secret")
    assert_equal Failure(:invalid_credentials), plain_authenticator.call(username: "ahmad", password: "wrong")
    assert_equal ["MPRT\\ahmad"], @directory.identities.uniq
  end

  test "a blank password never reaches a plain server, where it would be an unauthenticated bind" do
    @directory = PlainDirectory.new

    ["", " ", nil].each do |password|
      assert_equal Failure(:invalid_credentials), plain_authenticator.call(username: "ahmad", password:)
    end
    assert_equal 0, @directory.accepted
  end

  test "the default LDAPS transport never falls back to plaintext against a plain server" do
    @directory = PlainDirectory.new
    config = directory_config(ad_host: "localhost", ad_port: @directory.port.to_s)
    authenticator = Authentication::LdapAuthenticator.new(config:, logger: ->(**entry) { @log << entry })

    assert_equal Failure(:directory_unavailable), authenticator.call(username: "ahmad", password: "right")
    assert_empty @directory.binds
  end

  private

  def plain_authenticator
    config = directory_config(ad_host: "localhost", ad_port: @directory.port.to_s, ad_transport: "plain")
    Authentication::LdapAuthenticator.new(config:, logger: ->(**entry) { @log << entry })
  end
end
