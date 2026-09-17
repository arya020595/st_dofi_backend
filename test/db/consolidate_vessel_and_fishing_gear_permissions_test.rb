require "test_helper"
require Rails.root.join("db/migrate/20260917100000_consolidate_vessel_and_fishing_gear_permissions")

class ConsolidateVesselAndFishingGearPermissionsTest < ActiveSupport::TestCase
  test "moves fishing gear grants to the matching vessel permissions" do
    fishing_gear = create(:permission, code: "companies_fishing_gears.update")
    vessel = create(:permission, code: "companies_vessels.update")
    fishing_gear_approval = create(:permission, code: "companies_fishing_gear_approvals.approve")
    vessel_approval = create(:permission, code: "companies_vessel_approvals.approve")
    role = create(:role, permissions: [fishing_gear, fishing_gear_approval])

    migration = ConsolidateVesselAndFishingGearPermissions.new
    migration.suppress_messages { migration.up }

    assert_equal [vessel_approval.code, vessel.code], role.reload.permissions.order(:code).pluck(:code)
    assert_nil Permission.find_by(code: fishing_gear.code)
    assert_nil Permission.find_by(code: fishing_gear_approval.code)
  end
end
