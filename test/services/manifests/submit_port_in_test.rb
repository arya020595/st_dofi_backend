require "test_helper"

module Manifests
  class SubmitPortInTest < ActiveSupport::TestCase
    setup do
      @actor = create(:user)
      @approver = create_admin_recipient("manifest_approvals.approve")
      @verifier = create_admin_recipient("capture_report_verifications.verify")
    end

    test "commercial skipped manifest notifies jetty approvers, not capture verifiers" do
      manifest = at_sea_manifest("commercial", skipped: true)

      assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success?

      assert_equal({ approver: ["manifest.port_in_review_required"], verifier: [] }, notifications_by_recipient)
      assert_equal "awaiting_port_in_approval", manifest.manifest_status
    end

    test "small-scale skipped manifest completes and notifies nobody" do
      manifest = at_sea_manifest("small_scale_full_time", skipped: true)

      assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success?

      assert_equal({ approver: [], verifier: [] }, notifications_by_recipient)
      assert_equal "completed", manifest.manifest_status
    end

    test "manifest with capture reports notifies capture verifiers" do
      manifest = at_sea_manifest("commercial", skipped: false)
      create(:capture_report, manifest: manifest)

      assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success?

      assert_equal({ approver: [], verifier: ["manifest.capture_report_review_required"] },
                   notifications_by_recipient)
      assert_equal "capture_report_submitted", manifest.manifest_status
    end

    test "fails when the capture report is neither submitted nor skipped" do
      manifest = at_sea_manifest("commercial", skipped: false)

      assert_predicate SubmitPortIn.call(manifest, actor: @actor), :failure?
    end

    private

    def at_sea_manifest(category, skipped:)
      manifest = create(:manifest, fisherman_category: category)
      manifest.submit_port_out!
      manifest.approve_port_out! if manifest.may_approve_port_out?
      manifest.update!(capture_report_skipped: skipped)
      manifest
    end

    def notifications_by_recipient
      { approver: @approver.notifications.pluck(:notification_type),
        verifier: @verifier.notifications.pluck(:notification_type) }
    end
  end
end
