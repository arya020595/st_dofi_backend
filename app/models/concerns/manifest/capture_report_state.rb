# What the manifest knows about its Capture Reports: whether the step can be submitted, and how the reports
# currently stand.
module Manifest::CaptureReportState
  extend ActiveSupport::Concern

  included do
    validate :capture_reports_absent_when_skipped, if: :capture_report_skipped_changed?
  end

  def capture_report_ready? = capture_report_skipped? || capture_reports.exists?

  # Row-level aggregate for the Manifest List "Catch Report" column: worst-status-wins across this
  # manifest's capture_reports, mirroring CompanyProfile#owner_contact's simple has_many-aggregation
  # pattern.
  def capture_report_overview_status
    return "skipped" if capture_report_skipped?
    return "not_initiated" if capture_reports.none?
    return "amendment_required" if capture_reports.any?(&:needs_amendment?)
    return "verified" if capture_reports.all?(&:verified?)

    "pending_verification"
  end

  private

  # A report is either skipped or submitted, never both — otherwise skipping would silently drop reports
  # that were never verified. CaptureReport enforces the other direction.
  def capture_reports_absent_when_skipped
    return unless capture_report_skipped? && capture_reports.exists?

    errors.add(:base, "Capture report cannot be skipped once capture reports have been created")
  end
end
