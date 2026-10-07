require "test_helper"

# AASM is the transition table only. What follows a transition (status cascade, amendment snapshot, review stamp)
# lives in Manifests::Transition / CaptureReports::Transition, so production code must go through them and never
# fire a lifecycle event directly. Those services fire events dynamically, so a literal call is always a bypass.
class LifecycleEventsOnlyInServicesTest < ActiveSupport::TestCase
  MANIFEST_EVENTS = %i[port_out port_in manifest].flat_map { |machine| Manifest.aasm(machine).events.map(&:name) }
  REPORT_RECEIVER_EVENTS = /\b\w*report\w*\.(?:verify|request_amendment|resubmit)!/
  LITERAL_CALL = /\.(?:#{MANIFEST_EVENTS.join('|')})!|#{REPORT_RECEIVER_EVENTS}/

  test "no production code fires a manifest or capture report event directly" do
    offenders = Rails.root.glob("app/**/*.rb").flat_map { |file| bypasses_in(file) }

    assert_empty offenders, "Fire lifecycle events through Manifests::Transition / CaptureReports::Transition:\n" \
                            "#{offenders.join("\n")}"
  end

  private

  def bypasses_in(file)
    File.readlines(file).each_with_index.filter_map do |line, index|
      next if line.strip.start_with?("#") || !line.match?(LITERAL_CALL)

      "#{file.relative_path_from(Rails.root)}:#{index + 1}: #{line.strip}"
    end
  end
end
