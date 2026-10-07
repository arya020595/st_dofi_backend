require "test_helper"

module CaptureReports
  class VerifyTest < ActiveSupport::TestCase
    test "verifying the last report does not re-notify jetty approvers already told at port-in submit" do
      approver = create_admin_recipient("manifest_approvals.approve")
      manifest = create(:manifest, fisherman_category: "commercial")
      manifest.submit_port_out!
      manifest.approve_port_out!
      report = create(:capture_report, manifest: manifest)
      manifest.submit_port_in!

      assert_predicate Verify.call(report, actor: create(:user)), :success?

      assert_equal "awaiting_port_in_approval", manifest.reload.manifest_status
      assert_empty approver.notifications.pluck(:notification_type)
    end
  end
end
