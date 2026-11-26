require "test_helper"

class RoleDirectoryManagedTest < ActiveSupport::TestCase
  setup do
    @officer = create(:role, kind: Role::DOFI_OFFICER)
    @custom = create(:role, name: "Inspector")
    @jetty_manager = create(:role, kind: Role::JETTY_MANAGER)
    @fisherman = create(:role, :fisherman)
  end

  test "the DoFi Officer platform minus Jetty Managers, including custom roles that have no kind" do
    assert_equal [@officer, @custom].sort_by(&:id), Role.directory_managed.sort_by(&:id)
    assert_equal [true, true, false, false],
                 [@officer, @custom, @jetty_manager, @fisherman].map(&:directory_managed?)
  end
end
