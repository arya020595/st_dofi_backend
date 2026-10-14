module Notifications
  class ManifestEventJob < ApplicationJob
    # This boundary runs after commit; queue failures cannot undo the completed business action.
    def self.enqueue_safely(user_ids:, attributes:, manifest_id:, error_reporter: Rails.error)
      job = new(user_ids: user_ids, attributes: attributes, manifest_id: manifest_id)
      job.enqueue
      return if job.successfully_enqueued?

      error = job.enqueue_error || ActiveJob::EnqueueError.new("Manifest notification was not enqueued")
      report_enqueue_failure(error, attributes, manifest_id, error_reporter)
    rescue SolidQueue::Job::EnqueueError, ActiveJob::EnqueueError => e
      report_enqueue_failure(e, attributes, manifest_id, error_reporter)
    end

    def self.report_enqueue_failure(error, attributes, manifest_id, error_reporter)
      event = attributes.fetch(:notification_type).delete_prefix("manifest.")
      error_reporter.report(error, handled: true, context: { event: event, manifest_id: manifest_id })
    end
    private_class_method :report_enqueue_failure

    def perform(user_ids:, attributes:, manifest_id:)
      manifest = Manifest.find_by(id: manifest_id)
      return unless manifest

      PublishToUsers.call(users: User.kept.where(id: user_ids), attributes: attributes, resource: manifest)
    end
  end
end
