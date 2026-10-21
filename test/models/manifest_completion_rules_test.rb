require "test_helper"

# Executable version of the "Completion Rules" table: a manifest completes only when its Port-In leg and its
# Capture Report leg are both settled. Jetty Manager approval and DoFi Officer verification are independent, so
# every row that involves both is also run in the opposite order.
class ManifestCompletionRulesTest < ActiveSupport::TestCase
  COMMERCIAL = "commercial".freeze
  SMALL_SCALE = "small_scale_full_time".freeze

  # category, Jetty Manager approved Port-In?, capture reports, expected manifest_status
  RULES = [
    [COMMERCIAL, false, :unverified,      "capture_report_submitted"],
    [COMMERCIAL, true,  :unverified,      "capture_report_submitted"],
    [COMMERCIAL, true,  :needs_amendment, "capture_report_submitted"],
    [COMMERCIAL, false, :verified,        "awaiting_port_in_approval"],
    [COMMERCIAL, true,  :verified,        "completed"],
    [COMMERCIAL, false, :skipped,         "awaiting_port_in_approval"],
    [COMMERCIAL, true,  :skipped,         "completed"],
    [SMALL_SCALE, false, :unverified,     "capture_report_submitted"],
    [SMALL_SCALE, false, :verified,       "completed"],
    [SMALL_SCALE, false, :skipped,        "completed"]
  ].freeze

  RULES.each do |category, jetty_approved, reports, expected_status|
    orders = jetty_approved && reports == :verified ? %i[approve_first verify_first] : %i[approve_first]

    orders.each do |order|
      label = "#{category}, port-in #{jetty_approved ? 'approved' : 'not approved'}, reports #{reports} " \
              "(#{order}) -> #{expected_status}"

      test label do
        manifest, report = submitted_manifest(category, skipped: reports == :skipped)
        steps = [-> { approve_port_in(manifest) if jetty_approved }, -> { review(report, reports) }]
        steps.reverse! if order == :verify_first
        steps.each(&:call)

        assert_equal expected_status, manifest.reload.manifest_status
      end
    end
  end

  private

  def submitted_manifest(category, skipped:)
    manifest = create(:manifest, fisherman_category: category, capture_report_skipped: skipped)
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value! if manifest.may_approve_port_out?
    report = create(:capture_report, manifest: manifest) unless skipped
    Manifests::SubmitPortIn.call(manifest, actor: nil).value!
    [manifest, report]
  end

  def approve_port_in(manifest) = Manifests::ApprovePortIn.call(manifest, actor: nil).value!

  def review(report, reports)
    case reports
    when :verified
      CaptureReports::Verify.call(report, actor: nil).value!
    when :needs_amendment
      CaptureReports::RequestAmendment.call(report, actor: nil, remarks: "Correct the catch quantity").value!
    end
  end
end
