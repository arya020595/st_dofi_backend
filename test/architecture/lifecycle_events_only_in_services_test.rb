require "test_helper"

# AASM is the transition table only. The per-action services (app/services/manifests, app/services/capture_reports)
# fire every lifecycle event themselves, so nothing else (controller, model, job, another service) may fire one:
# it would skip the amendment remarks, the manifest status follow-up and the notifications.
class LifecycleEventsOnlyInServicesTest < ActiveSupport::TestCase
  MANIFEST_EVENTS = %i[port_out port_in manifest].flat_map { |machine| Manifest.aasm(machine).events.map(&:name) }
  REPORT_RECEIVER_EVENTS = /\b\w*report\w*\.(?:verify|request_amendment|resubmit)!/
  LITERAL_CALL = /\.(?:#{MANIFEST_EVENTS.join('|')})!|#{REPORT_RECEIVER_EVENTS}/
  LIFECYCLE_SERVICES = %w[app/services/manifests/ app/services/capture_reports/].freeze

  test "only the manifest and capture report services fire lifecycle events" do
    offenders = Rails.root.glob("app/**/*.rb").flat_map { |file| outside_lifecycle_services(file) }

    assert_empty offenders, "Fire lifecycle events in app/services/manifests or app/services/capture_reports:\n" \
                            "#{offenders.join("\n")}"
  end

  test "every service that completes a manifest also records the fishing gear usage" do
    offenders = Rails.root.glob("app/**/*.rb").select do |file|
      source = file.read
      source.include?(".complete_manifest!") && source.exclude?("RecordFishingGearUsage.call")
    end

    assert_empty offenders.map { |file| file.relative_path_from(Rails.root).to_s },
                 "A service that calls complete_manifest! must also call RecordFishingGearUsage"
  end

  private

  def outside_lifecycle_services(file)
    relative = file.relative_path_from(Rails.root).to_s
    return [] if LIFECYCLE_SERVICES.any? { |directory| relative.start_with?(directory) }

    File.readlines(file).each_with_index.filter_map do |line, index|
      next if line.strip.start_with?("#") || !line.match?(LITERAL_CALL)

      "#{relative}:#{index + 1}: #{line.strip}"
    end
  end
end
