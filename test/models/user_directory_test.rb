require "test_helper"

class UserDirectoryTest < ActiveSupport::TestCase
  include DirectoryTestSupport

  setup do
    @staff = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER), password: "Password123!")
    @custom = create(:user, role: create(:role, name: "Inspector"), password: "Password123!")
    @jetty = create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER),
                                                  password: "Password123!")
    @fisherman = create(:user, :fins_governed_fisherman, password: "Password123!")
    @no_role = create(:user, role: nil, password: "Password123!")
  end

  test "directory_managed covers every non-external role and nothing else" do
    assert_equal [@staff, @custom].sort_by(&:id), User.directory_managed.sort_by(&:id)
    assert_equal [true, true, false, false, false],
                 [@staff, @custom, @jetty, @fisherman, @no_role].map(&:directory_managed?)
  end

  test "a staff user's local password is never accepted, whichever directory mode is running" do
    [directory_config, mock_directory_config].each do |config|
      with_directory_config(config) do
        assert_not @staff.valid_password?("Password123!")
        assert_not @custom.valid_password?("Password123!")
      end
    end
  end

  test "Jetty Manager, Fisherman and role-less accounts are unaffected" do
    with_directory_config(directory_config) do
      assert @jetty.valid_password?("Password123!")
      assert @fisherman.valid_password?("Password123!")
      assert @no_role.valid_password?("Password123!")
    end
  end
end
