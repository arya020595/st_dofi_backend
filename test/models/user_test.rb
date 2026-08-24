require "test_helper"
class UserTest < ActiveSupport::TestCase
  test "approve! transitions a pending user to active" do
    user = create(:user, status: "pending")

    user.approve!

    assert_equal "active", user.status
  end

  test "approve! raises when the user is not pending" do
    user = create(:user, status: "active")

    assert_raises(AASM::InvalidTransition) { user.approve! }
    assert_not user.may_approve?
  end

  test "reject! transitions a pending user to rejected" do
    user = create(:user, status: "pending")

    user.reject!

    assert_equal "rejected", user.status
  end

  test "reject! raises when the user is not pending" do
    user = create(:user, status: "rejected")

    assert_raises(AASM::InvalidTransition) { user.reject! }
    assert_not user.may_reject?
  end

  test "approval_status_label maps AASM states to display labels" do
    assert_equal "Pending", build(:user, status: "pending").approval_status_label
    assert_equal "Approved", build(:user, status: "active").approval_status_label
    assert_equal "Rejected", build(:user, status: "rejected").approval_status_label
  end

  test "officer? is true only for the DoFi Officer role" do
    officer_role = create(:role, kind: Role::DOFI_OFFICER)
    jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER)

    assert_predicate build(:user, role: officer_role), :officer?
    assert_not build(:user, role: jetty_manager_role).officer?
    assert_not build(:user, role: nil).officer?
  end

  test "invalid without position, unit, or username for the DoFi Officer role" do
    officer_role = create(:role, kind: Role::DOFI_OFFICER)
    user = build(:user, role: officer_role, position: nil, unit: nil, username: nil)
    user.valid?

    assert_includes user.errors.attribute_names, :position
    assert_includes user.errors.attribute_names, :unit
    assert_includes user.errors.attribute_names, :username
  end

  test "email is never required, even for the DoFi Officer role" do
    officer_role = create(:role, kind: Role::DOFI_OFFICER)
    user = build(:user, role: officer_role, email: "", position: "Administrator", unit: "HQ")

    assert_predicate user, :valid?
  end

  test "normalizes ic_number before validation" do
    user = build(:user, ic_number: "01-123 456")

    user.valid?

    assert_equal "01123456", user.normalized_ic_number
  end

  test "active fisherman_status requires claimed identity timestamps" do
    company_profile = create(:company_profile)
    role = create(:role, :fisherman, company_profile: company_profile)
    user = build(:user, role: role, company_profile: company_profile, ic_number: "01-444444",
                        registration_type: "Commercial", fisherman_status: "active")

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :fisherman_status

    user.claimed_at = Time.current
    user.brunei_id_verified_at = Time.current

    assert_predicate user, :valid?
  end
end

# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  brunei_id_verified_at      :datetime
#  contact_no                 :string
#  designation                :string
#  discarded_at               :datetime
#  doft_registration_no       :string
#  email                      :string           default(""), not null
#  encrypted_password         :string           default(""), not null
#  ic_number                  :string
#  jti                        :string           not null
#  name                       :string           not null
#  position                   :string
#  preferred_locale           :string           default("en"), not null
#  registration_type          :string
#  rejection_reason           :text
#  remember_created_at        :datetime
#  reset_password_sent_at     :datetime
#  reset_password_token       :string
#  status                     :string           default("active"), not null
#  unit                       :string
#  username                   :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  company_profile_contact_id :uuid
#  company_profile_id         :uuid
#  employee_id                :string
#  role_id                    :uuid
#
# Indexes
#
#  index_users_on_company_profile_contact_id  (company_profile_contact_id)
#  index_users_on_company_profile_id          (company_profile_id)
#  index_users_on_discarded_at                (discarded_at)
#  index_users_on_email                       (email) UNIQUE WHERE ((email)::text <> ''::text)
#  index_users_on_employee_id                 (employee_id) UNIQUE
#  index_users_on_ic_number                   (ic_number) UNIQUE WHERE (ic_number IS NOT NULL)
#  index_users_on_jti                         (jti) UNIQUE
#  index_users_on_reset_password_token        (reset_password_token) UNIQUE
#  index_users_on_role_id                     (role_id)
#  index_users_on_username                    (username) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (company_profile_contact_id => company_profile_contacts.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (role_id => roles.id)
#
