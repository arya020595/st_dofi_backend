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

  test "sends vessel, crew, and document approval notifications to the default profile owner" do
    company_profile = create(:company_profile)
    owner = create_fisherman_recipient(company_profile, default_owner: true)
    vessel = create(:companies_vessel, company_profile:)
    crew = create(:companies_crew, company_profile:)
    document = create(:companies_document, company_profile:)

    Notifications::ProfilingPublisher.call(event: :vessel_approved, resource: vessel)
    Notifications::ProfilingPublisher.call(event: :crew_approved, resource: crew)
    Notifications::ProfilingPublisher.call(event: :document_approved, resource: document)

    assert_equal %w[profiling.crew_approved profiling.document_approved profiling.vessel_approved],
                 owner.notifications.order(:notification_type).pluck(:notification_type)
    assert_equal "Vessel / Boat #{vessel.vessel_name} has been approved.",
                 owner.notifications.find_by!(resource_type: "CompaniesVessel", resource_id: vessel.id).message
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
