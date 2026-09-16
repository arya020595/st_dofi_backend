require "test_helper"

class Notifications::ProfilingPublisherTest < ActiveSupport::TestCase
  test "sends a vessel amendment notification with remarks to the default profile owner" do
    vessel = create(:companies_vessel)
    owner = create_fisherman_recipient(vessel.company_profile, default_owner: true)
    create_fisherman_recipient(vessel.company_profile)
    vessel.request_amendment!(remarks: "Please attach the current vessel licence.")

    Notifications::ProfilingPublisher.call(event: :vessel_amendment_required, resource: vessel)

    notification = owner.notifications.sole

    assert_equal "profiling.vessel_amendment_required", notification.notification_type
    assert_equal vessel.id, notification.resource_id
    assert_equal "Please attach the current vessel licence.", notification.metadata["amendment_remarks"]
  end

  private

  def create_fisherman_recipient(company_profile, default_owner: false)
    role = create(:role, :fisherman, company_profile:, is_default: default_owner,
                                     name: default_owner ? "Owner" : "Crew Role")
    create(:user, role:, company_profile:, fisherman_status: "active", registration_type: "Commercial",
                  ic_number: "01-#{SecureRandom.random_number(10**8).to_s.rjust(8, '0')}",
                  claimed_at: Time.current, brunei_id_verified_at: Time.current)
  end
end
