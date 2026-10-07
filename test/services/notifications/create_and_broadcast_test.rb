require "test_helper"

class Notifications::CreateAndBroadcastTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "persists the notification before broadcasting its unread summary" do
    user = create(:user)

    messages = capture_broadcasts(NotificationsChannel.broadcasting_for(user)) do
      @notification = Notifications::CreateAndBroadcast.call(
        user:,
        attributes: {
          notification_type: "manifest.port_out_approved",
          title: "Port-Out Approved",
          message: "Your manifest has been approved."
        }
      )
    end

    assert_predicate @notification, :persisted?
    assert_equal 1, messages.size
    assert_equal 1, messages.first.fetch("count")
  end

  test "broadcast failure preserves the notification and reports the handled error" do
    broadcaster = Object.new
    broadcaster.define_singleton_method(:broadcast_to) { |*| raise IOError, "broadcast unavailable" }
    reports = []
    reporter = Object.new
    reporter.define_singleton_method(:report) { |error, **options| reports << [error, options] }

    notification = Notifications::CreateAndBroadcast.new(broadcaster:, error_reporter: reporter).call(
      user: create(:user), attributes: { notification_type: "manifest.port_out_approved", title: "Approved",
                                         message: "Your manifest has been approved." }
    )

    assert_equal [true, IOError, { handled: true, context: { notification_id: notification.id } }],
                 [notification.persisted?, reports.first.first.class, reports.first.last]
  end
end
