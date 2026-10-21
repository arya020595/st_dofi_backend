require "test_helper"
require_relative "../../support/committed_database_test"

module Manifests
  class SubmitPortInTest < ActiveSupport::TestCase
    include CommittedDatabaseTest
    include ActiveJob::TestHelper

    self.use_transactional_tests = false

    setup do
      @actor = create(:user)
      @approver = create_admin_recipient("manifest_approvals.approve")
      @verifier = create_admin_recipient("capture_report_verifications.verify")
    end

    test "commercial skipped manifest notifies jetty approvers, not capture verifiers" do
      manifest = at_sea_manifest("commercial", skipped: true)

      perform_enqueued_jobs { assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success? }

      assert_equal({ approver: ["manifest.port_in_review_required"], verifier: [] }, notifications_by_recipient)
      assert_equal "awaiting_port_in_approval", manifest.manifest_status
    end

    test "small-scale skipped manifest completes and notifies nobody" do
      manifest = at_sea_manifest("small_scale_full_time", skipped: true)

      perform_enqueued_jobs { assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success? }

      assert_equal({ approver: [], verifier: [] }, notifications_by_recipient)
      assert_equal "completed", manifest.manifest_status
    end

    test "commercial manifest with capture reports notifies jetty approvers and capture verifiers" do
      manifest = at_sea_manifest("commercial", skipped: false)
      create(:capture_report, manifest: manifest)

      perform_enqueued_jobs { assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success? }

      assert_equal({ approver: ["manifest.port_in_review_required"],
                     verifier: ["manifest.capture_report_review_required"] },
                   notifications_by_recipient)
      assert_equal "capture_report_submitted", manifest.manifest_status
    end

    test "small-scale manifest with capture reports notifies capture verifiers only" do
      manifest = at_sea_manifest("small_scale_full_time", skipped: false)
      create(:capture_report, manifest: manifest)

      perform_enqueued_jobs { assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success? }

      assert_equal({ approver: [], verifier: ["manifest.capture_report_review_required"] },
                   notifications_by_recipient)
      assert_equal "capture_report_submitted", manifest.manifest_status
    end

    test "commercial manifest with verified reports only notifies jetty approvers" do
      manifest = at_sea_manifest("commercial", skipped: false)
      report = create(:capture_report, manifest: manifest)
      CaptureReports::Verify.call(report, actor: @actor).value!
      clear_enqueued_jobs

      perform_enqueued_jobs { assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success? }

      assert_equal({ approver: ["manifest.port_in_review_required"], verifier: [] }, notifications_by_recipient)
      assert_equal "verified", report.reload.capture_report_status
    end

    test "submission preserves amendment requests without notifying verifiers before resubmission" do
      manifest = at_sea_manifest("commercial", skipped: false)
      report = create(:capture_report, manifest: manifest)
      CaptureReports::RequestAmendment.call(report, actor: @actor, remarks: "Fix catch").value!
      clear_enqueued_jobs

      perform_enqueued_jobs { assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success? }

      assert_equal({ approver: ["manifest.port_in_review_required"], verifier: [] }, notifications_by_recipient)
      assert_equal "needs_amendment", report.reload.capture_report_status
    end

    %w[small_scale_company small_scale_full_time small_scale_part_time].each do |category|
      test "#{category} with verified reports completes on submission without review notification" do
        manifest = at_sea_manifest(category, skipped: false)
        report = create(:capture_report, manifest: manifest)
        CaptureReports::Verify.call(report, actor: @actor).value!
        clear_enqueued_jobs

        perform_enqueued_jobs { assert_predicate SubmitPortIn.call(manifest, actor: @actor), :success? }

        assert_equal "completed", manifest.reload.manifest_status
        assert_equal({ approver: [], verifier: [] }, notifications_by_recipient)
      end
    end

    test "fails when the capture report is neither submitted nor skipped" do
      manifest = at_sea_manifest("commercial", skipped: false)

      assert_predicate SubmitPortIn.call(manifest, actor: @actor), :failure?
    end

    private

    def at_sea_manifest(category, skipped:)
      manifest = create(:manifest, fisherman_category: category)
      Manifests::SubmitPortOut.call(manifest, actor: nil).value!
      Manifests::ApprovePortOut.call(manifest, actor: nil).value! if manifest.may_approve_port_out?
      manifest.update!(capture_report_skipped: skipped)
      clear_enqueued_jobs
      @sent_during_setup = Notification.pluck(:id)
      manifest
    end

    # Only what the action under test sent; the Port-Out services notified the approver during setup.
    def notifications_by_recipient
      { approver: new_notification_types(@approver), verifier: new_notification_types(@verifier) }
    end

    def new_notification_types(user)
      user.notifications.where.not(id: @sent_during_setup).pluck(:notification_type)
    end
  end
end
