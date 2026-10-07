require "test_helper"

module Manifests
  class SkipCaptureReportTest < ActiveSupport::TestCase
    test "fails without skipping once capture reports exist" do
      manifest = create(:manifest, fisherman_category: "commercial")
      Manifests::SubmitPortOut.call(manifest, actor: nil).value!
      Manifests::ApprovePortOut.call(manifest, actor: nil).value!
      create(:capture_report, manifest: manifest)
      reason = create(:manifest_skip_reason)

      result = SkipCaptureReport.call(manifest, skip_reason_id: reason.id)

      assert_predicate result, :failure?
      assert_not manifest.reload.capture_report_skipped?
    end
  end
end
