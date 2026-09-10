require "test_helper"

# Exercises the real db/seeds/permissions.rb (not a re-derived copy of its logic) to guard the
# invariant that every officially defined permission resource ends up fully classified for the
# "Add User Role" UI grouping. Runs inside this test's transaction, so nothing seeded here persists
# beyond it.
class SeedsPermissionsTest < ActiveSupport::TestCase
  test "every PERMISSION_GROUPS resource is fully classified after seeding" do
    load Rails.root.join("db/seeds/permissions.rb")

    PERMISSION_GROUPS.each_key do |resource|
      permission = Permission.find_by(resource: resource)

      assert permission, "no permission was seeded for resource #{resource}"
      assert permission.section.present? && permission.section_order.present? && permission.resource_order.present?,
             "#{resource} is missing grouping metadata (section=#{permission.section.inspect}, " \
             "section_order=#{permission.section_order.inspect}, resource_order=#{permission.resource_order.inspect})"
    end
  end
end
