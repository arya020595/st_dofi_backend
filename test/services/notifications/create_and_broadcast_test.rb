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
end
