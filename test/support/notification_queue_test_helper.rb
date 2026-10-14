module NotificationQueueTestHelper
  def with_failing_notification_queue(error)
    adapter = ActiveJob::QueueAdapters::TestAdapter.new
    adapter.define_singleton_method(:enqueue) { |_job| raise error }
    original = Notifications::ManifestEventJob._test_adapter
    Notifications::ManifestEventJob.enable_test_adapter(adapter)
    yield
  ensure
    Notifications::ManifestEventJob.enable_test_adapter(original)
  end

  def recording_error_reporter(reports)
    Object.new.tap do |reporter|
      reporter.define_singleton_method(:report) { |error, **options| reports << [error, options] }
    end
  end
end
