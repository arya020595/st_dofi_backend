require "test_helper"

module Manifests
  # The decision table behind Manifests::Advance: given the legs' statuses, which manifest_status event is next.
  class LifecycleRulesTest < ActiveSupport::TestCase
    # manifest_status, category, port_out, port_in, reports, expected next event
    TABLE = [
      ["draft", "commercial", "pending", "draft", [], :begin_port_out_review],
      ["draft", "small_scale_full_time", "submitted", "draft", [], :advance_to_sea],
      ["draft", "commercial", "draft", "draft", [], nil],
      ["awaiting_port_out_approval", "commercial", "approved", "draft", [], :advance_to_sea],
      ["awaiting_port_out_approval", "commercial", "amendment_required", "draft", [], nil],
      ["at_sea", "commercial", "approved", "pending", ["pending_verification"], :complete_capture_report],
      ["at_sea", "small_scale_full_time", "submitted", "submitted", ["pending_verification"], :complete_capture_report],
      ["at_sea", "commercial", "approved", "draft", [], nil],
      ["capture_report_submitted", "commercial", "approved", "pending", ["pending_verification"], nil],
      ["capture_report_submitted", "commercial", "approved", "approved", ["pending_verification"], nil],
      ["capture_report_submitted", "commercial", "approved", "approved", ["needs_amendment"], nil],
      ["capture_report_submitted", "commercial", "approved", "pending", ["verified"], :begin_port_in_review],
      ["capture_report_submitted", "commercial", "approved", "amendment_required", ["verified"], nil],
      ["capture_report_submitted", "commercial", "approved", "approved", ["verified"], :complete_manifest],
      ["capture_report_submitted", "commercial", "approved", "approved", %w[verified pending_verification], nil],
      ["capture_report_submitted", "small_scale_full_time", "submitted", "submitted", ["verified"], :complete_manifest],
      ["capture_report_submitted", "small_scale_full_time", "submitted", "submitted", ["pending_verification"], nil],
      ["awaiting_port_in_approval", "commercial", "approved", "pending", ["verified"], nil],
      ["awaiting_port_in_approval", "commercial", "approved", "approved", ["verified"], :complete_manifest],
      ["completed", "commercial", "approved", "approved", ["verified"], nil]
    ].freeze

    TABLE.each do |(status, category, port_out, port_in, reports, expected)|
      test "#{category} #{status} out=#{port_out} in=#{port_in} reports=#{reports.inspect} -> #{expected.inspect}" do
        manifest = create(:manifest, fisherman_category: category)
        manifest.update_columns(manifest_status: status, port_out_status: port_out, port_in_status: port_in) # rubocop:disable Rails/SkipsModelValidations
        reports.each { |state| create(:capture_report, manifest: manifest, capture_report_status: state) }

        assert_equal [expected], [LifecycleRules.new(manifest).next_event]
      end
    end

    test "a skipped capture report settles the report leg" do
      manifest = create(:manifest, fisherman_category: "commercial", capture_report_skipped: true)
      manifest.update_columns(manifest_status: "capture_report_submitted", port_in_status: "pending") # rubocop:disable Rails/SkipsModelValidations

      assert_equal :begin_port_in_review, LifecycleRules.new(manifest).next_event
    end

    test "no capture reports and not skipped never settles the report leg" do
      manifest = create(:manifest, fisherman_category: "small_scale_full_time")
      manifest.update_columns(manifest_status: "capture_report_submitted", port_in_status: "submitted") # rubocop:disable Rails/SkipsModelValidations

      assert_nil LifecycleRules.new(manifest).next_event
    end
  end
end
