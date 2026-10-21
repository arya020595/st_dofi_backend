require "test_helper"

module Manifests
  class ApprovePortOutTest < ActiveSupport::TestCase
    test "approving a commercial Port-Out sends the manifest to sea" do
      manifest = create(:manifest, fisherman_category: "commercial")
      SubmitPortOut.call(manifest, actor: nil).value!

      assert_equal %w[pending awaiting_port_out_approval], [manifest.port_out_status, manifest.manifest_status]

      assert_predicate ApprovePortOut.call(manifest, actor: nil), :success?
      assert_equal %w[approved at_sea], [manifest.reload.port_out_status, manifest.manifest_status]
    end

    test "returns Failure and changes nothing when the Port-Out is not pending" do
      manifest = create(:manifest, fisherman_category: "commercial")

      assert_predicate ApprovePortOut.call(manifest, actor: nil), :failure?
      assert_equal %w[draft draft], [manifest.reload.port_out_status, manifest.manifest_status]
    end

    test "the actor reaches the manifest status history row the approval caused" do
      actor = create(:user)
      manifest = create(:manifest, fisherman_category: "commercial")
      SubmitPortOut.call(manifest, actor: nil).value!

      ApprovePortOut.call(manifest, actor: actor).value!

      history = manifest.manifest_histories.find_by!(status_type: "manifest_status", action: "advance_to_sea!")

      assert_equal actor.id, history.changed_by_id
    end

    test "clears the Port-Out amendment remarks once the Port-Out is approved" do
      manifest = create(:manifest, fisherman_category: "commercial")
      SubmitPortOut.call(manifest, actor: nil).value!
      RequestAmendmentPortOut.call(manifest, actor: nil, remarks: "Fix the port-out time").value!

      assert_equal "Fix the port-out time", manifest.reload.port_out_amendment_remarks

      ResubmitPortOut.call(manifest, actor: nil).value!
      ApprovePortOut.call(manifest, actor: nil).value!

      assert_nil manifest.reload.port_out_amendment_remarks
    end
  end
end
