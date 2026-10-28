require "test_helper"

class AdminUserSeedTest < ActiveSupport::TestCase
  include DirectoryTestSupport

  SEED = Rails.root.join("db/seeds/admin_user.rb")

  setup { create(:role, kind: Role::DOFI_OFFICER, name: "DoFi Officer") }

  def seed(config: staging_directory_config, username: nil, &)
    with_directory_config(config) do
      with_env({ "ADMIN_AD_USERNAME" => username }) { capture_io { load SEED } }
    end
    yield if block_given?
  end

  def admin = User.find_by!(email: "admin@dofi.gov.bn")

  test "outside production it creates the superadmin as a mock account, with no usable password" do
    seed

    assert_equal ["mprt/dof-001", true], [admin.username, admin.officer?]
    assert_not BCrypt::Password.new(admin.encrypted_password).is_password?("ChangeMe123!")
    assert_not admin.valid_password?("ChangeMe123!")
  end

  test "ADMIN_AD_USERNAME is used when given, with or without the domain prefix" do
    seed(username: "Azri.Nizam")

    assert_equal "mprt/azri.nizam", admin.username
  end

  test "running it twice keeps one user and never changes an existing one" do
    seed(username: "mprt/first.admin")
    before = admin.attributes
    seed(username: "mprt/other.admin")

    assert_equal 1, User.where(email: "admin@dofi.gov.bn").count
    assert_equal before, admin.attributes
  end

  test "an existing user is left alone even if it is missing fields" do
    create(:user, email: "admin@dofi.gov.bn", username: nil, position: nil, unit: nil, role: nil)
    seed(username: "mprt/new.admin")

    assert_nil admin.username
    assert_nil admin.position
  end

  test "production needs the superadmin's real AD username and never falls back to a placeholder" do
    [nil, "", "   ", "not valid!", "OTHER\\someone", "a" * 65].each do |bad|
      error = assert_raises(ArgumentError, bad.inspect) { seed(config: production_directory_config, username: bad) }

      assert_match(/ADMIN_AD_USERNAME/, error.message)
    end
    assert_not User.exists?(email: "admin@dofi.gov.bn")
  end

  test "production creates the superadmin with the real AD username" do
    seed(config: production_directory_config, username: "MPRT/Real.Admin")

    assert_equal "mprt/real.admin", admin.username
    assert_not BCrypt::Password.new(admin.encrypted_password).is_password?("ChangeMe123!")
  end
end
