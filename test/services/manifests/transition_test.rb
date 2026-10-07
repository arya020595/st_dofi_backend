require "test_helper"

module Manifests
  class TransitionTest < ActiveSupport::TestCase
    test "fires the leg event and carries the manifest status along" do
      manifest = create(:manifest, fisherman_category: "small_scale_full_time")

      assert_predicate Transition.call(manifest, :submit_port_out), :success?
      assert_equal %w[submitted at_sea], [manifest.reload.port_out_status, manifest.manifest_status]
    end

    test "a commercial port-out waits for Jetty Manager review, then approval sends the manifest to sea" do
      manifest = create(:manifest, fisherman_category: "commercial")

      Transition.call(manifest, :submit_port_out)

      assert_equal %w[pending awaiting_port_out_approval], [manifest.port_out_status, manifest.manifest_status]

      Transition.call(manifest, :approve_port_out)

      assert_equal %w[approved at_sea], [manifest.reload.port_out_status, manifest.manifest_status]
    end

    test "returns Failure and changes nothing when the event is not allowed" do
      manifest = create(:manifest, fisherman_category: "commercial")

      assert_predicate Transition.call(manifest, :approve_port_in), :failure?
      assert_equal %w[draft draft], [manifest.reload.port_in_status, manifest.manifest_status]
    end

    test "stores the remarks on a port-in amendment request and clears them on resubmit" do
      manifest = create(:manifest, fisherman_category: "commercial")
      Transition.call(manifest, :submit_port_out)
      Transition.call(manifest, :approve_port_out)
      create(:capture_report, manifest: manifest)
      Transition.call(manifest, :submit_port_in)

      Transition.call(manifest, :request_amendment_port_in, remarks: "Fix the port-in time")

      assert_equal "Fix the port-in time", manifest.reload.port_in_amendment_remarks

      Transition.call(manifest, :resubmit_port_in)

      assert_nil manifest.reload.port_in_amendment_remarks
    end

    test "the actor reaches the cascaded manifest history row" do
      actor = create(:user)
      manifest = create(:manifest, fisherman_category: "commercial")
      Transition.call(manifest, :submit_port_out)

      Transition.call(manifest, :approve_port_out, actor: actor)

      history = manifest.manifest_histories.find_by!(status_type: "manifest_status", action: "advance_to_sea!")

      assert_equal actor.id, history.changed_by_id
    end

    test "events on the model only move their own status; the cascade belongs to Transition" do
      manifest = create(:manifest, fisherman_category: "small_scale_full_time")

      manifest.submit_port_out!

      assert_equal %w[submitted draft], [manifest.port_out_status, manifest.manifest_status]
    end
  end
end
