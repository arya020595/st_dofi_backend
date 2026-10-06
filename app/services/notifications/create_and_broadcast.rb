module Notifications
  class CreateAndBroadcast
    def self.call(...) = new.call(...)

    def initialize(broadcaster: NotificationsChannel, error_reporter: Rails.error)
      @broadcaster = broadcaster
      @error_reporter = error_reporter
    end

    def call(user:, attributes:, resource: nil)
      notification = persist!(user:, attributes:, resource:)

      broadcast(notification)
      notification
    end

    private

    attr_reader :broadcaster, :error_reporter

    def persist!(user:, attributes:, resource:)
      Notification.transaction do
        Notification.create!(notification_attributes(user:, attributes:, resource:))
      end
    end

    def notification_attributes(user:, attributes:, resource:)
      attributes.merge(
        user:,
        resource_type: resource_type_for(resource),
        resource_id: resource&.id
      )
    end

    def resource_type_for(resource)
      resource.class.base_class.name if resource
    end

    def broadcast(notification)
      broadcaster.broadcast_to(notification.user, payload_for(notification))
    rescue StandardError => e
      error_reporter.report(e, handled: true, context: { notification_id: notification.id })
    end

    def payload_for(notification)
      {
        type: "notification_summary",
        count: notification.user.notifications.unread.count,
        info: NotificationBlueprint.render_as_hash(notification)
      }
    end
  end
end
