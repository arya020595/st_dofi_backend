# A skipped capture report has nothing for a DoFi Officer to verify. Small-scale (Part-Time / Full-Time /
# Company) Port-In then needs no approval at all, while commercial Port-In goes straight to Jetty Manager
# review. Before this, every skipped manifest was left at port_in `pending` (and manifest
# `capture_report_submitted`), waiting for a Jetty Manager who was never notified. Reroute the rows already
# stuck there. Small-scale manifests that also carry capture reports are left for manual review: those
# reports were never verified and completing would drop their fishing-gear usage.
class RerouteSkippedManifestsByCategory < ActiveRecord::Migration[8.1]
  SMALL_SCALE = "('small_scale_company', 'small_scale_full_time', 'small_scale_part_time')".freeze
  REMARKS = "System reroute: skipped capture report rules by category".freeze

  SMALL_SCALE_STUCK = <<~SQL.squish.freeze
    fisherman_category IN #{SMALL_SCALE}
      AND capture_report_skipped
      AND port_in_status = 'pending'
      AND manifest_status IN ('capture_report_submitted', 'awaiting_port_in_approval')
      AND NOT EXISTS (SELECT 1 FROM capture_reports WHERE capture_reports.manifest_id = manifests.id)
  SQL

  COMMERCIAL_STUCK = <<~SQL.squish.freeze
    fisherman_category = 'commercial'
      AND capture_report_skipped
      AND port_in_status = 'pending'
      AND manifest_status = 'capture_report_submitted'
  SQL

  def up
    safety_assured do
      reroute!(SMALL_SCALE_STUCK, port_in_status: "submitted", manifest_status: "completed")
      reroute!(COMMERCIAL_STUCK, manifest_status: "awaiting_port_in_approval")
    end
  end

  # Nothing to restore: the previous state was the bug, and the history rows keep the audit trail.
  def down; end

  private

  # Records one history row per changed column (written before the UPDATE so from_state still holds the
  # current value), then applies all changes in a single UPDATE. Once updated, the predicate no longer
  # matches, which is also what makes the migration idempotent.
  def reroute!(predicate, changes)
    changes.each { |column, to_state| record_history(column, to_state, predicate) }

    assignments = changes.map { |column, to_state| "#{column} = #{quote(to_state)}" }.join(", ")
    execute "UPDATE manifests SET #{assignments}, updated_at = now() WHERE #{predicate}"
  end

  def record_history(status_type, to_state, predicate)
    execute <<~SQL.squish
      INSERT INTO manifest_histories
        (manifest_id, action, status_type, from_state, to_state, remarks, metadata, created_at, updated_at)
      SELECT id, 'system_reroute', #{quote(status_type.to_s)}, #{status_type}, #{quote(to_state)},
             #{quote(REMARKS)}, '{}', now(), now()
      FROM manifests WHERE #{predicate}
    SQL
  end
end
