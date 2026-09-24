require "test_helper"

# Exercises the real db/seeds/permissions.rb (not a re-derived copy of its logic) to guard the
# invariant that every officially defined permission resource ends up fully classified for the
# "Add User Role" UI grouping. Runs inside this test's transaction, so nothing seeded here persists
# beyond it.
class SeedsPermissionsTest < ActiveSupport::TestCase
  test "every catalog permission is seeded with canonical metadata" do
    load Rails.root.join("db/seeds/permissions.rb")

    Permission::Catalog::ENTRIES.each do |entry|
      permission = Permission.find_by!(code: entry.fetch(:code))

      assert_equal entry.values_at(:platform_scope, :resource, :section, :section_order, :resource_order),
                   [permission.platform_scope, permission.resource, permission.section,
                    permission.section_order, permission.resource_order]
    end
  end
end
