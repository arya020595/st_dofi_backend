require "test_helper"

class Notifications::ManifestPublisherTest < ActiveSupport::TestCase
  test "port-out review notification is sent only to authorized admin approvers" do
    manifest = create(:manifest)
    approver = create_admin_recipient("manifest_approvals.approve")
    create_admin_recipient("capture_report_verifications.verify")

    Notifications::ManifestPublisher.call(event: :port_out_review_required, manifest:)

    assert_equal ["manifest.port_out_review_required"], approver.notifications.pluck(:notification_type)
  end

  test "port-out decision notification reaches the profile owner and manifest creator" do
    manifest = create(:manifest)
    owner = create_fisherman_recipient(manifest.company_profile, default_owner: true)
    creator = create_fisherman_recipient(manifest.company_profile)
    manifest.update!(created_by: creator)

    Notifications::ManifestPublisher.call(event: :port_out_approved, manifest:)

    assert_equal 1, owner.notifications.count
    assert_equal 1, creator.notifications.count
    assert_equal "manifest.port_out_approved", owner.notifications.first.notification_type
  end

  test "capture-report review notification is sent only to authorized verifiers" do
    manifest = create(:manifest)
    verifier = create_admin_recipient("capture_report_verifications.verify")
    create_admin_recipient("manifest_approvals.approve")

    Notifications::ManifestPublisher.call(event: :capture_report_review_required, manifest:)

    assert_equal ["manifest.capture_report_review_required"], verifier.notifications.pluck(:notification_type)
  end

  private

  def create_admin_recipient(permission_code)
    permission = create(:permission, code: permission_code)
    role = create(:role, permissions: [permission])
    create(:user, role: role)
  end

  def create_fisherman_recipient(company_profile, default_owner: false)
    role = fisherman_role_for(company_profile, default_owner:)
    create(:user, **fisherman_user_attributes(company_profile, role))
  end

  def fisherman_role_for(company_profile, default_owner:)
    attributes = { company_profile: company_profile, is_default: default_owner }
    attributes[:name] = "Owner" if default_owner
    create(:role, :fisherman, **attributes)
  end

  def fisherman_ic_number
    "01-#{SecureRandom.random_number(10**8).to_s.rjust(8, '0')}"
  end

  def fisherman_user_attributes(company_profile, role)
    {
      role: role,
      company_profile: company_profile,
      fisherman_status: "active",
      registration_type: "Commercial",
      ic_number: fisherman_ic_number,
      claimed_at: Time.current,
      brunei_id_verified_at: Time.current
    }
  end
end
