require "test_helper"

module CaptureReports
  class VerifyTest < ActiveSupport::TestCase
    test "verifying the last report does not re-notify jetty approvers already told at port-in submit" do
      approver = create_admin_recipient("manifest_approvals.approve")
      manifest = create(:manifest, fisherman_category: "commercial")
      Manifests::SubmitPortOut.call(manifest, actor: nil).value!
      Manifests::ApprovePortOut.call(manifest, actor: nil).value!
      report = create(:capture_report, manifest: manifest)
      Manifests::SubmitPortIn.call(manifest, actor: nil).value!

      assert_no_difference -> { approver.notifications.count } do
        assert_predicate Verify.call(report, actor: create(:user)), :success?
      end

      assert_equal "awaiting_port_in_approval", manifest.reload.manifest_status
    end
  end
end
