require "test_helper"
require Rails.root.join("db/migrate/20260911090000_enforce_single_resource_permission_contract")

class EnforceSingleResourcePermissionContractTest < ActiveSupport::TestCase
  test "backfill preserves approval and verification access and is idempotent" do
    source_codes = %w[
      manifests.list manifests.view manifest_approvals.approve manifest_approvals.amendment
      capture_reports.list capture_reports.view capture_report_verifications.amendment
      companies_vessel_approvals.amendment companies_crew_approvals.amendment
      companies_fishing_gear_approvals.amendment companies_document_approvals.amendment
    ]
    role = create(:role, kind: Role::DOFI_OFFICER,
                         permissions: source_codes.map { |code| create(:permission, code:) })
    migration = EnforceSingleResourcePermissionContract.new

    migration.suppress_messages { migration.up }
    first_count = role.reload.permissions.count
    migration.suppress_messages { migration.up }

    expected = %w[
      permissions.list manifest_approvals.list manifest_approvals.view
      manifest_approvals.approve_port_out manifest_approvals.approve_port_in
      manifest_approvals.request_amendment_port_out manifest_approvals.request_amendment_port_in
      capture_report_verifications.list capture_report_verifications.view
      capture_report_verifications.request_amendment companies_vessel_approvals.request_amendment
      companies_crew_approvals.request_amendment companies_fishing_gear_approvals.request_amendment
      companies_document_approvals.request_amendment
    ]

    assert_empty expected - role.reload.permissions.pluck(:code)
    assert_equal first_count, role.permissions.count
    assert_equal role.permissions.count, role.permission_roles.distinct.count
  end

  test "backfill grants canonical dashboard and permission-list access to existing roles" do
    dashboard = create(:permission, code: "dashboard.view")
    role = create(:role, permissions: [dashboard])
    other_role = create(:role)

    run_migration

    assert_includes role.reload.permissions.pluck(:code), "dashboard.list"
    assert_includes role.permissions.pluck(:code), "permissions.list"
    assert_includes other_role.reload.permissions.pluck(:code), "permissions.list"
  end

  private

  def run_migration
    migration = EnforceSingleResourcePermissionContract.new
    migration.suppress_messages { migration.up }
  end
end
