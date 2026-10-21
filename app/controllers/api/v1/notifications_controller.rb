module Api
  module V1
    class NotificationsController < ApplicationController
      include RansackSearchable

      before_action :set_notification, only: :read

      def index
        notifications = apply_ransack_search(current_user.notifications.recent_first, default_sort: "created_at desc")
        pagy, records = pagy(:offset, notifications)
        render json: {
          status: "success",
          data: NotificationBlueprint.render_as_hash(records),
          meta: pagination_meta(pagy).merge(unread_count: current_user.notifications.unread.count)
        }
      end

      def read
        @notification.mark_read!
        render json: {
          status: "success",
          data: NotificationBlueprint.render_as_hash(@notification),
          meta: { unread_count: current_user.notifications.unread.count }
        }
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params.expect(:id))
      end
    end
  end
end
