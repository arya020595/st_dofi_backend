require "test_helper"
require Rails.root.join("db/migrate/20260917110000_consolidate_capture_report_detail_permissions")

class ConsolidateCaptureReportDetailPermissionsTest < ActiveSupport::TestCase
  test "moves fisherman detail access to capture report update and removes legacy permissions" do
    company = create(:company_profile)
    source = create(:permission, code: "fish_capture_details.bulk_sync")
    target = create(:permission, code: "capture_reports.update")
    target.update_columns(platform_scope: "shared", section: "capture_reports", section_order: 11) # rubocop:disable Rails/SkipsModelValidations
    fisherman_role = create(:role, :fisherman, company_profile: company, permissions: [source])
    officer_role = create(:role, permissions: [source, target])

    migration = ConsolidateCaptureReportDetailPermissions.new
    migration.suppress_messages { migration.up }

    assert_equal [target.id], fisherman_role.reload.permission_ids
    assert_equal [[], false], [officer_role.reload.permission_ids, Permission.exists?(source.id)]
    assert_equal ["fisherman", "manifest", 2, 3],
                 target.reload.attributes.values_at("platform_scope", "section", "section_order", "resource_order")
  end
end
