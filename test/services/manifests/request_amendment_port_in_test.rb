require "test_helper"

module Manifests
  class RequestAmendmentPortInTest < ActiveSupport::TestCase
    setup do
      @manifest = create(:manifest, fisherman_category: "commercial")
      SubmitPortOut.call(@manifest, actor: nil).value!
      ApprovePortOut.call(@manifest, actor: nil).value!
      create(:capture_report, manifest: @manifest)
      SubmitPortIn.call(@manifest, actor: nil).value!
    end

    test "stores the remarks on the manifest and clears them when the fisherman resubmits" do
      assert_predicate RequestAmendmentPortIn.call(@manifest, actor: nil, remarks: "Fix the port-in time"), :success?
      assert_equal "Fix the port-in time", @manifest.reload.port_in_amendment_remarks

      ResubmitPortIn.call(@manifest, actor: nil).value!

      assert_nil @manifest.reload.port_in_amendment_remarks
    end

    test "returns Failure and keeps the remarks empty when the Port-In is not pending" do
      RequestAmendmentPortIn.call(@manifest, actor: nil, remarks: "Fix the port-in time").value!

      result = RequestAmendmentPortIn.call(@manifest, actor: nil, remarks: "Second request")

      assert_predicate result, :failure?
      assert_equal "Fix the port-in time", @manifest.reload.port_in_amendment_remarks
    end

    test "a Port-In left pending behind verified reports moves on to Jetty Manager review first" do
      @manifest.capture_reports.each { |report| CaptureReports::Verify.call(report, actor: nil).value! }
      @manifest.update_columns(manifest_status: "capture_report_submitted") # rubocop:disable Rails/SkipsModelValidations

      RequestAmendmentPortIn.call(@manifest, actor: nil, remarks: "Fix the port-in time").value!

      assert_equal %w[amendment_required awaiting_port_in_approval],
                   [@manifest.reload.port_in_status, @manifest.manifest_status]
    end
  end
end
