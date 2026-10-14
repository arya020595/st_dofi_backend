require "test_helper"
require_relative "../../support/notification_queue_test_helper"

class Notifications::ManifestEventJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include NotificationQueueTestHelper

  setup do
    @reports = []
    @reporter = recording_error_reporter(@reports)
    @payload = { user_ids: [], attributes: { notification_type: "manifest.port_in_approved" },
                 manifest_id: SecureRandom.uuid }
  end

  test "Solid Queue errors are reported without raising" do
    error = SolidQueue::Job::EnqueueError.new("queue unavailable")
    with_failing_notification_queue(error) { enqueue_notification }

    assert_equal error, @reports.sole.first
    assert_equal({ handled: true, context: { event: "port_in_approved", manifest_id: @payload[:manifest_id] } },
                 @reports.sole.last)
  end

  test "Active Job unsuccessful enqueue is reported even when enqueue returns false" do
    error = ActiveJob::EnqueueError.new("adapter rejected job")
    with_failing_notification_queue(error) { enqueue_notification }

    assert_equal error, @reports.sole.first
    assert_empty enqueued_jobs
  end

  test "aborted enqueue without an exception reports a fallback error" do
    callback = -> { throw(:abort) }
    Notifications::ManifestEventJob.set_callback(:enqueue, :before, callback)
    enqueue_notification

    assert_instance_of ActiveJob::EnqueueError, @reports.sole.first
    assert_empty enqueued_jobs
  ensure
    Notifications::ManifestEventJob.skip_callback(:enqueue, :before, callback)
  end

  test "successful enqueue serializes only the notification payload" do
    assert_enqueued_with(job: Notifications::ManifestEventJob, args: [@payload]) { enqueue_notification }
    assert_empty @reports
  end

  test "unexpected programming errors are not swallowed" do
    error = NoMethodError.new("unexpected adapter bug")

    assert_raises(NoMethodError) do
      with_failing_notification_queue(error) { enqueue_notification }
    end
    assert_empty @reports
  end

  private

  def enqueue_notification
    Notifications::ManifestEventJob.enqueue_safely(**@payload, error_reporter: @reporter)
  end
end
