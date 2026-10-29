# Helpers for the Active Directory tests: build a DirectoryConfig without touching ENV, and make the app see it.
module DirectoryTestSupport
  include Dry::Monads[:result]

  LDAP_ENV = {
    "AD_MODE" => "ldap", "AD_HOST" => "ad1.mprt.test, ad2.mprt.test", "AD_PORT" => "3269",
    "AD_NETBIOS_DOMAIN" => "MPRT", "AD_DNS_DOMAIN" => "MPRT.EG.GOV.BN", "AD_BIND_FORMAT" => "netbios"
  }.freeze
  MOCK_PASSWORD = "mock-ad-password".freeze # the same fake value test_helper puts in AD_MOCK_PASSWORD

  def directory_config(rails_env: "test", **overrides)
    env = LDAP_ENV.merge(overrides.transform_keys { it.to_s.upcase }).compact
    Authentication::DirectoryConfig.load(env, rails_env:)
  end

  def mock_directory_config(**overrides)
    directory_config(ad_mode: "mock", ad_mock_password: MOCK_PASSWORD, **overrides)
  end

  # Makes the whole app (Warden strategy, User#valid_password?, services built with their defaults) see `config`.
  def with_directory_config(config)
    original = Authentication::DirectoryConfig.method(:current)
    Authentication::DirectoryConfig.define_singleton_method(:current) { config }
    yield
  ensure
    Authentication::DirectoryConfig.define_singleton_method(:current, original)
  end

  # Stands in for Authentication::LdapAuthenticator#call (no directory server involved), as built by OfficerLogin.
  def with_ldap_result(result)
    original = Authentication::LdapAuthenticator.instance_method(:call)
    Authentication::LdapAuthenticator.define_method(:call) { |**| result }
    yield
  ensure
    Authentication::LdapAuthenticator.define_method(:call, original)
  end

  def production_directory_config
    Authentication::DirectoryConfig.load(LDAP_ENV.merge("DEPLOY_ENV" => "production"), rails_env: "production")
  end

  def staging_directory_config
    Authentication::DirectoryConfig.load({ "AD_MODE" => "mock", "DEPLOY_ENV" => "staging" }, rails_env: "production")
  end

  # Sets ENV variables for the block (nil removes one) and restores them after.
  def with_env(vars)
    saved = vars.keys.index_with { ENV.fetch(it, nil) }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
