require "test_helper"
require Rails.root.join("db/migrate/20260910110000_expand_canonical_permissions")

class ExpandCanonicalPermissionsTest < ActiveSupport::TestCase
  test "backfill materializes legacy fisherman access and is idempotent" do
    company = create(:company_profile)
    legacy = create(:permission, code: "manifest_form.create", platform_scope: Permission::SHARED_PLATFORM)
    role = create(:role, :fisherman, company_profile: company, permissions: [legacy])
    migration = ExpandCanonicalPermissions.new

    migration.suppress_messages { migration.up }
    first_count = role.reload.permissions.count
    migration.suppress_messages { migration.up }

    expected = %w[
      manifests.create manifests.update manifests.submit_port_out manifests.resubmit_port_out
      manifests.submit_port_in manifests.resubmit_port_in manifests.skip_capture_report
      capture_reports.create capture_reports.update capture_reports.resubmit
      fish_capture_details.create fish_capture_details.update fish_capture_details.delete
      fish_capture_details.bulk_sync fishing_gear_details.create fishing_gear_details.update
      fishing_gear_details.delete
    ]

    assert_empty expected - role.reload.permissions.pluck(:code)
    assert_equal first_count, role.permissions.count
    assert_equal role.permissions.count, role.permission_roles.distinct.count
  end

  test "backfill preserves officer manifest, profile, dictionary, and verification access" do
    legacy_codes = %w[
      manifest_list.view manifest_form.create profiling.update dictionaries.update
      capture_report_verifications.view
    ]
    role = create(:role, kind: Role::DOFI_OFFICER,
                         permissions: legacy_codes.map { |code| create(:permission, code:) })

    run_migration

    expected = %w[
      manifests.view manifests.create manifests.update manifests.submit_port_out manifests.submit_port_in
      company_profiles.update company_profile_contacts.update dictionary_groups.update
      dictionary_families.update capture_reports.list capture_reports.view
    ]

    assert_empty expected - role.reload.permissions.pluck(:code)
  end

  test "backfill preserves same-resource and vessel-derived capabilities" do
    company = create(:company_profile)
    source_codes = %w[
      manifest_minor_fishermen.create manifest_expenses.update capture_reports.update
      companies_vessels.view companies_vessels.update profiling.view
    ]
    role = create(:role, :fisherman, company_profile: company,
                                     permissions: source_codes.map { |code| create(:permission, code:) })

    run_migration

    expected = %w[
      manifest_minor_fishermen.delete manifest_expenses.create capture_reports.resubmit
      fish_capture_details.create fish_capture_details.update fish_capture_details.delete
      fishing_gear_details.create fishing_gear_details.update fishing_gear_details.delete
      companies_vessels.images companies_fishing_gears.update company_profiles.list company_profiles.view
      company_profiles.update company_profile_contacts.update
    ]

    assert_empty expected - role.reload.permissions.pluck(:code)
  end

  test "rerun repairs canonical catalog metadata" do
    permission = create(:permission, code: "manifests.view")
    # Deliberately bypass the catalog callback to emulate stale production metadata.
    permission.update_columns(name: "Wrong", platform_scope: "fisherman", resource: "wrong", # rubocop:disable Rails/SkipsModelValidations
                              section: "wrong", section_order: 99, resource_order: 99)

    run_migration

    assert_equal ["View", "shared", "manifests", "manifest", 2, 1],
                 permission.reload.attributes.values_at(
                   "name", "platform_scope", "resource", "section", "section_order", "resource_order"
                 )
  end

  private

  def run_migration
    migration = ExpandCanonicalPermissions.new
    migration.suppress_messages { migration.up }
  end
end
