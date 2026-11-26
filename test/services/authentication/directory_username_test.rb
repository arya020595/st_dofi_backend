require "test_helper"

class Authentication::DirectoryUsernameTest < ActiveSupport::TestCase
  def username(text, domain: "MPRT") = Authentication::DirectoryUsername.new(text, domain:)

  test "every way of typing the same person gives the same AD short name" do
    ["azri.nizam", "Azri.Nizam", "MPRT/Azri.Nizam", "mprt\\azri.nizam", "  MPRT/AZRI.NIZAM  "].each do |typed|
      assert_equal "azri.nizam", username(typed).short, typed
    end
  end

  test "candidates cover the typed text, the short name and the domain-prefixed form" do
    assert_equal ["azri.nizam", "mprt/azri.nizam"], username("Azri.Nizam").stored_candidates
    assert_equal ["mprt/azri.nizam", "azri.nizam"], username("MPRT/Azri.Nizam").stored_candidates
    assert_equal ["mprt\\azri.nizam", "azri.nizam", "mprt/azri.nizam"], username("MPRT\\Azri.Nizam").stored_candidates
  end

  test "another domain is not stripped and is not a valid short name" do
    assert_nil username("OTHER\\azri").short
    assert_nil username("other/azri").short
  end

  test "only one domain prefix is removed" do
    assert_nil username("mprt/mprt/azri").short
  end

  test "text that cannot be an AD name has no short name" do
    ["", "   ", "a b", "azri,dc=x", "azri*", "a" * 65, "azri\0"].each do |typed|
      assert_nil username(typed).short, typed.inspect
    end
  end

  test "text that cannot be a stored username has no candidates, so it never reaches the database" do
    ["", "azri\0", "a\nb", "a" * 256].each do |typed|
      assert_empty username(typed).stored_candidates, typed.inspect
    end
  end

  test "without a configured domain nothing is stripped" do
    assert_equal ["mprt/azri"], username("MPRT/azri", domain: "").stored_candidates
  end
end
