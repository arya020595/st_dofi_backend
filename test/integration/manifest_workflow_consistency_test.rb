require "test_helper"
require_relative "../support/committed_database_test"
require "timeout"

class ManifestWorkflowConsistencyTest < ActiveSupport::TestCase
  include CommittedDatabaseTest
  include ActiveJob::TestHelper

  self.use_transactional_tests = false

  setup do
    @manifest = create(:manifest)
    Manifests::SubmitPortOut.call(@manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(@manifest, actor: nil).value!
    @report = CaptureReports::Create.call(@manifest, {}).value!
    @gear = create(:companies_fishing_gear, :approved, company_profile: @manifest.company_profile,
                                                       companies_vessel: @manifest.companies_vessel, usage_value: 5)
    create(:fishing_gear_detail, capture_report: @report, companies_fishing_gear: @gear, quantity: 2)
    create_admin_recipient("manifest_approvals.approve")
    clear_enqueued_jobs
  end

  test "submission preserves a verified report and its review stamp" do
    reviewer = create(:user)
    CaptureReports::Verify.call(@report, actor: reviewer).value!
    stamp = @report.reload.attributes.slice("reviewed_by_id", "reviewed_at")

    Manifests::SubmitPortIn.call(@manifest, actor: nil).value!

    assert_equal "verified", @report.reload.capture_report_status
    assert_equal stamp, @report.attributes.slice("reviewed_by_id", "reviewed_at")
    assert_equal "awaiting_port_in_approval", @manifest.reload.manifest_status
    Manifests::ApprovePortIn.call(@manifest, actor: nil).value!

    assert_completed_once
  end

  test "capture report verification does not wait for port-out approval" do
    manifest = create(:manifest)
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    report = CaptureReports::Create.call(manifest, {}).value!
    CaptureReports::Verify.call(report, actor: nil).value!

    assert_equal "awaiting_port_out_approval", manifest.reload.manifest_status
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!

    assert_equal "verified", report.reload.capture_report_status
    assert_equal "at_sea", manifest.reload.manifest_status
  end

  test "new report returns a manifest awaiting port-in to capture report submitted" do
    submit_port_in
    CaptureReports::Verify.call(@report, actor: nil).value!
    actor = create(:user)

    added = CaptureReports::Create.call(@manifest, {}, actor: actor).value!
    Manifests::ApprovePortIn.call(@manifest, actor: nil).value!

    assert_equal "capture_report_submitted", @manifest.reload.manifest_status
    assert_equal actor.id, @manifest.manifest_histories.where(action: "complete_capture_report!").last.changed_by_id
    CaptureReports::Verify.call(added, actor: nil).value!

    assert_completed_once
    assert_predicate CaptureReports::Create.call(@manifest, {}), :failure?
  end

  test "approval and verification on separate connections complete exactly once" do
    submit_port_in
    results = race(
      -> { Manifest.find(@manifest.id) }, -> { CaptureReport.find(@report.id) },
      ->(manifest) { Manifests::ApprovePortIn.call(manifest, actor: nil) },
      ->(report) { CaptureReports::Verify.call(report, actor: nil) }
    )

    assert results.all?(&:success?)
    assert_completed_once
  end

  test "two requests loading the same pending report verify only once" do
    submit_port_in
    Manifests::ApprovePortIn.call(@manifest, actor: nil).value!
    results = race(
      -> { CaptureReport.find(@report.id) }, -> { CaptureReport.find(@report.id) },
      ->(report) { CaptureReports::Verify.call(report, actor: nil) },
      ->(report) { CaptureReports::Verify.call(report, actor: nil) }
    )

    assert_equal 1, results.count(&:success?)
    assert_equal 1, @manifest.manifest_histories.where(action: "verify!").count
    assert_completed_once
  end

  test "verification racing amendment allows exactly one transition from pending" do
    results = race(
      -> { CaptureReport.find(@report.id) }, -> { CaptureReport.find(@report.id) },
      ->(report) { CaptureReports::Verify.call(report, actor: nil) },
      ->(report) { CaptureReports::RequestAmendment.call(report, actor: nil, remarks: "Fix catch") }
    )

    assert_equal 1, results.count(&:success?)
    assert_equal 1, @manifest.manifest_histories.where(status_type: "capture_report_status").count
    if @report.reload.needs_amendment?
      assert_equal "Fix catch", @manifest.reload.capture_report_amendment_remarks
    else
      assert_nil @manifest.reload.capture_report_amendment_remarks
    end
  end

  test "editing gear quantities racing verification preserves the quantities used on completion" do
    submit_port_in
    Manifests::ApprovePortIn.call(@manifest, actor: nil).value!
    detail_id = @report.fishing_gear_details.sole.id
    results = race(
      -> { FishingGearDetail.find(detail_id) }, -> { CaptureReport.find(@report.id) },
      ->(detail) { FishingGearDetails::Update.call(detail, quantity: 9) },
      ->(report) { CaptureReports::Verify.call(report, actor: nil) }
    )

    quantity = FishingGearDetail.find(detail_id).quantity

    assert_equal(results.first.success? ? 9 : 2, quantity)
    assert_equal BigDecimal((5 + quantity).to_s), @gear.reload.usage_value
    assert_equal "completed", @manifest.reload.manifest_status
  end

  test "creating a report racing completion cannot leave a completed manifest with pending reports" do
    submit_port_in
    Manifests::ApprovePortIn.call(@manifest, actor: nil).value!
    race(
      -> { Manifest.find(@manifest.id) }, -> { CaptureReport.find(@report.id) },
      ->(manifest) { CaptureReports::Create.call(manifest, {}) },
      ->(report) { CaptureReports::Verify.call(report, actor: nil) }
    )

    @manifest.reload

    assert_equal !@manifest.capture_reports.unverified.exists?, @manifest.completed?
    assert_equal(@manifest.completed? ? BigDecimal("7") : BigDecimal("5"), @gear.reload.usage_value)
  end

  test "creating a report racing skip never persists both" do
    empty_manifest = create(:manifest, :small_scale)
    Manifests::SubmitPortOut.call(empty_manifest, actor: nil).value!
    reason = create(:manifest_skip_reason)
    results = race(
      -> { Manifest.find(empty_manifest.id) }, -> { Manifest.find(empty_manifest.id) },
      ->(manifest) { CaptureReports::Create.call(manifest, {}) },
      ->(manifest) { Manifests::SkipCaptureReport.call(manifest, skip_reason_id: reason.id) }
    )

    assert_equal 1, results.count(&:success?)
    assert_not empty_manifest.reload.capture_report_skipped? && empty_manifest.capture_reports.exists?
  end

  test "notifications wait for the outermost commit and retain the event metadata" do
    submit_port_in
    clear_enqueued_jobs
    ActiveRecord::Base.transaction do
      Manifests::ApprovePortIn.call(@manifest, actor: nil).value!

      assert_no_enqueued_jobs
      CaptureReports::Verify.call(@report, actor: nil).value!

      assert_no_enqueued_jobs
    end

    payloads = enqueued_jobs.map { |job| ActiveJob::Arguments.deserialize(job[:args]).first }
    approval = payloads.find { |payload| payload[:attributes][:notification_type] == "manifest.port_in_approved" }

    assert_equal "capture_report_submitted", approval[:attributes][:metadata][:manifest_status]
    assert_equal "completed", @manifest.reload.manifest_status
  end

  test "verification snapshot is prepared under the parent lock before a concurrent approval" do
    submit_port_in
    clear_enqueued_jobs
    snapshot_ready = Queue.new
    release_snapshot = Queue.new
    approval_ready = Queue.new
    threads = []
    with_verification_snapshot_barrier(snapshot_ready, release_snapshot) do
      threads << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          CaptureReports::Verify.call(CaptureReport.find(@report.id), actor: nil)
        end
      end
      verifier_pid = Timeout.timeout(10) { snapshot_ready.pop }
      threads << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          approval_ready << connection.select_value("SELECT pg_backend_pid()")
          Manifests::ApprovePortIn.call(Manifest.find(@manifest.id), actor: nil)
        end
      end
      approver_pid = Timeout.timeout(10) { approval_ready.pop }
      wait_for_manifest_lock(approver_pid, verifier_pid)
      release_snapshot << true
      results = Timeout.timeout(20) { threads.map(&:value) }

      assert results.all?(&:success?)
    end
    payloads = enqueued_jobs.map { |job| ActiveJob::Arguments.deserialize(job[:args]).first }
    verification = payloads.find do |payload|
      payload[:attributes][:notification_type] == "manifest.capture_report_verified"
    end

    assert_equal "awaiting_port_in_approval", verification[:attributes][:metadata][:manifest_status]
    assert_equal "completed", @manifest.reload.manifest_status
  ensure
    stop_threads(threads)
  end

  test "rollback after completion restores statuses history and gear usage and never enqueues notifications" do
    submit_port_in
    Manifests::ApprovePortIn.call(@manifest, actor: nil).value!
    history_count = @manifest.manifest_histories.count
    clear_enqueued_jobs
    ActiveRecord::Base.transaction do
      CaptureReports::Verify.call(@report, actor: nil).value!
      raise ActiveRecord::Rollback
    end

    assert_equal "pending_verification", @report.reload.capture_report_status
    assert_nil @report.reviewed_at
    assert_equal "capture_report_submitted", @manifest.reload.manifest_status
    assert_equal history_count, @manifest.manifest_histories.count
    assert_equal BigDecimal("5"), @gear.reload.usage_value
    assert_no_enqueued_jobs
  end

  test "completion persistence failure rolls back the preceding report event and history" do
    submit_port_in
    Manifests::ApprovePortIn.call(@manifest, actor: nil).value!
    history_count = @manifest.manifest_histories.count
    clear_enqueued_jobs
    @report.manifest.define_singleton_method(:complete_manifest!) { |**| raise ActiveRecord::RecordInvalid, self }

    assert_raises(ActiveRecord::RecordInvalid) { CaptureReports::Verify.call(@report, actor: nil) }

    assert_equal "pending_verification", @report.reload.capture_report_status
    assert_equal history_count, @manifest.manifest_histories.count
    assert_equal BigDecimal("5"), @gear.reload.usage_value
    assert_no_enqueued_jobs
  end

  test "repeated transitions do not add history usage or notifications" do
    submit_port_in
    Manifests::ApprovePortIn.call(@manifest, actor: nil).value!
    CaptureReports::Verify.call(@report, actor: nil).value!
    history_count = @manifest.manifest_histories.count
    clear_enqueued_jobs

    assert_predicate Manifests::ApprovePortIn.call(@manifest, actor: nil), :failure?
    assert_predicate CaptureReports::Verify.call(@report, actor: nil), :failure?
    assert_equal history_count, @manifest.manifest_histories.count
    assert_equal BigDecimal("7"), @gear.reload.usage_value
    assert_no_enqueued_jobs
  end

  private

  def submit_port_in
    Manifests::SubmitPortIn.call(@manifest, actor: nil).value!
  end

  def assert_completed_once
    assert_equal "completed", @manifest.reload.manifest_status
    assert_equal 1, @manifest.manifest_histories.where(action: "complete_manifest!").count
    assert_equal BigDecimal("7"), @gear.reload.usage_value
  end

  # Both objects are loaded before either service runs. No sleeps: separate connections synchronize at a barrier.
  def race(load_first, load_second, first, second)
    ready = Queue.new
    start = Queue.new
    threads = [[load_first, first], [load_second, second]].map do |load, action|
      race_thread(load, action, ready, start)
    end
    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { start << true }
    Timeout.timeout(20) { threads.map(&:value) }
  ensure
    stop_threads(threads)
  end

  def race_thread(load, action, ready, start)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        record = load.call
        ready << true
        start.pop
        action.call(record)
      end
    end
  end

  def with_verification_snapshot_barrier(ready, release)
    original = Notifications::ManifestPublisher.method(:enqueue)
    Notifications::ManifestPublisher.define_singleton_method(:enqueue) do |**arguments|
      next original.call(**arguments) unless arguments[:event] == :capture_report_verified

      ready << ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
      release.pop
      original.call(**arguments)
    end
    yield
  ensure
    Notifications::ManifestPublisher.define_singleton_method(:enqueue, original)
  end

  def wait_for_manifest_lock(approver_pid, verifier_pid)
    Timeout.timeout(10) do
      loop do
        break if manifest_lock_blocked?(approver_pid, verifier_pid)

        Thread.pass
      end
    end
  end

  def manifest_lock_blocked?(approver_pid, verifier_pid)
    # PostgreSQL lock state changes while we poll; never reuse a Rails query-cache result.
    ActiveRecord::Base.uncached do
      ActiveRecord::Base.connection.select_value(
        "SELECT #{verifier_pid.to_i} = ANY(pg_blocking_pids(#{approver_pid.to_i}))"
      )
    end
  end

  def stop_threads(threads)
    threads&.each { |thread| thread.kill if thread.alive? }
    threads&.each(&:join)
  end
end
