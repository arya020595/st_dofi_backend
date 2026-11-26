# The contract LdapAuthenticator and MockLdapAuthenticator share, so OfficerLogin can use either. Including tests
# define `authenticator`, `good_password` (accepted for "ahmad") and `bad_password` (rejected).
module DirectoryAuthenticatorContract
  include Dry::Monads[:result]

  def test_correct_password_authenticates
    assert_equal Success(:authenticated), authenticator.call(username: "ahmad", password: good_password)
  end

  def test_wrong_password_is_invalid_credentials
    assert_equal Failure(:invalid_credentials), authenticator.call(username: "ahmad", password: bad_password)
  end

  def test_blank_password_is_invalid_credentials
    [nil, "", "   "].each do |password|
      assert_equal Failure(:invalid_credentials), authenticator.call(username: "ahmad", password:)
    end
  end

  def test_blank_username_is_invalid_credentials
    assert_equal Failure(:invalid_credentials), authenticator.call(username: "", password: good_password)
  end

  def test_unusable_password_does_not_raise
    assert_equal Failure(:invalid_credentials), authenticator.call(username: "ahmad", password: "a\0b")
  end
end
