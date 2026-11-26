require "test_helper"
require_relative "../../support/directory_authenticator_contract"

class Authentication::MockLdapAuthenticatorTest < ActiveSupport::TestCase
  include DirectoryTestSupport
  include DirectoryAuthenticatorContract

  def authenticator = Authentication::MockLdapAuthenticator.new(config: mock_directory_config)
  def good_password = MOCK_PASSWORD
  def bad_password = "not-the-mock-password"

  test "the fixed password simulates an unavailable directory" do
    result = authenticator.call(username: "ahmad", password: Authentication::MockLdapAuthenticator::UNAVAILABLE_PASSWORD)

    assert_equal Failure(:directory_unavailable), result
  end

  test "a mock without a configured password never authenticates anyone" do
    mock = Authentication::MockLdapAuthenticator.new(config: directory_config(ad_mode: "mock"))

    assert_equal Failure(:directory_unavailable), mock.call(username: "ahmad", password: "anything")
    assert_equal Failure(:invalid_credentials), mock.call(username: "ahmad", password: "")
  end
end
