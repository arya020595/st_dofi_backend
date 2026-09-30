require "test_helper"
require Rails.root.join("db/migrate/20260930100000_reroute_skipped_manifests_by_category")

class RerouteSkippedManifestsByCategoryTest < ActiveSupport::TestCase
  test "completes stuck small-scale skipped manifests and records history" do
    manifest = stuck_manifest("small_scale_full_time")

    run_migration

    manifest.reload

    assert_equal %w[submitted completed], [manifest.port_in_status, manifest.manifest_status]
    assert_equal %w[port_in_status manifest_status],
                 ManifestHistory.where(manifest_id: manifest.id, action: "system_reroute").order(:status_type)
                                .reverse.map(&:status_type)
  end

  test "moves stuck commercial skipped manifests to jetty review and keeps port_in pending" do
    manifest = stuck_manifest("commercial")

    run_migration

    manifest.reload

    assert_equal %w[pending awaiting_port_in_approval], [manifest.port_in_status, manifest.manifest_status]
  end

  test "leaves non-skipped manifests and small-scale manifests that have capture reports alone" do
    not_skipped = stuck_manifest("small_scale_part_time", skipped: false)
    # Reports can't be created on a skipped manifest any more; this is legacy data the validation never saw.
    with_report = stuck_manifest("small_scale_part_time", skipped: false)
    create(:capture_report, manifest: with_report)
    with_report.update_column(:capture_report_skipped, true) # rubocop:disable Rails/SkipsModelValidations

    run_migration

    assert_equal "capture_report_submitted", not_skipped.reload.manifest_status
    assert_equal "capture_report_submitted", with_report.reload.manifest_status
    assert_equal "pending", with_report.port_in_status
  end

  test "is idempotent" do
    manifest = stuck_manifest("small_scale_company")

    2.times { run_migration }

    assert_equal 2, ManifestHistory.where(manifest_id: manifest.id, action: "system_reroute").count
  end

  private

  def stuck_manifest(category, skipped: true)
    manifest = create(:manifest, fisherman_category: category)
    manifest.update_columns(capture_report_skipped: skipped, port_in_status: "pending", # rubocop:disable Rails/SkipsModelValidations
                            manifest_status: "capture_report_submitted")
    manifest
  end

  def run_migration
    migration = RerouteSkippedManifestsByCategory.new
    migration.suppress_messages { migration.up }
  end
end
