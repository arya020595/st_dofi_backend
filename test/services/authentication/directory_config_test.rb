require "test_helper"

class Authentication::DirectoryConfigTest < ActiveSupport::TestCase
  include DirectoryTestSupport

  test "defaults to the mock directory outside production, where AD_MODE and DEPLOY_ENV may be unset" do
    %w[development test].each do |rails_env|
      config = Authentication::DirectoryConfig.load({}, rails_env:)

      assert_predicate config, :mock?, rails_env
      assert_equal rails_env, config.deploy_env
    end
  end

  test "a production RAILS_ENV needs an explicit AD_MODE and DEPLOY_ENV, with no defaults" do
    [{}, { "AD_MODE" => "ldap" }, { "DEPLOY_ENV" => "staging" }, { "AD_MODE" => "ldap", "DEPLOY_ENV" => "test" },
     { "AD_MODE" => "ldap", "DEPLOY_ENV" => "development" }].each do |env|
      assert_raises(ArgumentError, env.inspect) { Authentication::DirectoryConfig.load(env, rails_env: "production") }
    end
  end

  test "an unknown AD_MODE raises, whatever it is called" do
    %w[ldpa disabled off].each do |mode|
      error = assert_raises(ArgumentError) { Authentication::DirectoryConfig.load({ "AD_MODE" => mode }) }

      assert_match(/AD_MODE must be one of/, error.message)
    end
  end

  test "mock is refused when DEPLOY_ENV is production, with or without a mock password" do
    [{}, { "AD_MOCK_PASSWORD" => "x" }].each do |extra|
      env = { "AD_MODE" => "mock", "DEPLOY_ENV" => "production" }.merge(extra)
      error = assert_raises(ArgumentError) { Authentication::DirectoryConfig.load(env, rails_env: "production") }

      assert_match(/not allowed when DEPLOY_ENV=production/, error.message)
    end
  end

  test "production runs ldap and staging may run mock or ldap" do
    production = Authentication::DirectoryConfig.load({ "AD_MODE" => "ldap", "DEPLOY_ENV" => "production" },
                                                      rails_env: "production")

    assert_predicate production, :production?
    %w[mock ldap].each do |mode|
      staging = Authentication::DirectoryConfig.load({ "AD_MODE" => mode, "DEPLOY_ENV" => "staging" },
                                                     rails_env: "production")

      assert_equal [mode.to_sym, false], [staging.mode, staging.production?]
    end
  end

  test "AD_MODE and DEPLOY_ENV are case-insensitive" do
    config = Authentication::DirectoryConfig.load({ "AD_MODE" => " LDAP ", "DEPLOY_ENV" => "Staging" },
                                                  rails_env: "production")

    assert_equal [:ldap, "staging"], [config.mode, config.deploy_env]
  end

  test "parses hosts, port and timeouts, with LDAPS defaults" do
    config = directory_config

    assert_equal %w[ad1.mprt.test ad2.mprt.test], config.hosts
    assert_equal [3269, 3, 5], [config.port, config.connect_timeout, config.operation_timeout]
    assert_empty config.problems
  end

  test "a complete mock setup has no problems, a missing mock password is one" do
    assert_empty mock_directory_config.problems
    assert_equal ["AD_MOCK_PASSWORD is not set"], directory_config(ad_mode: "mock").problems
  end

  test "ldap mode reports what is missing or unsafe" do
    {
      { ad_host: "" } => /AD_HOST is not set/,
      { ad_host: "10.112.12.17" } => /not IP addresses/,
      { ad_host: "2001:db8::1" } => /not IP addresses/,
      { ad_port: "389" } => /AD_PORT/,
      { ad_port: "abc" } => /AD_PORT/,
      { ad_bind_format: "dn" } => /AD_BIND_FORMAT/,
      { ad_netbios_domain: "" } => /AD_NETBIOS_DOMAIN/,
      { ad_bind_format: "upn", ad_dns_domain: "" } => /AD_DNS_DOMAIN/,
      { ad_ca_file: "/nonexistent/ca.pem" } => /AD_CA_FILE/,
      { ad_connect_timeout: "0" } => /TIMEOUT/,
      { ad_operation_timeout: "soon" } => /TIMEOUT/
    }.each do |overrides, expected|
      problems = directory_config(**overrides).problems.join("; ")

      assert_match(expected, problems, "for #{overrides}")
    end
  end
end
