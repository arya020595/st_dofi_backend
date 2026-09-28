require "test_helper"
class UserTest < ActiveSupport::TestCase
  test "permission check accepts exactly one capability code" do
    user = build(:user)

    assert_raises(ArgumentError) { user.permission?("ports.view", "manifests.view") }
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

  test "officers and jetty managers get no fisherman_status" do
    officer = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER))
    jetty_manager = create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER))

    assert_nil officer.reload.fisherman_status
    assert_nil jetty_manager.reload.fisherman_status
  end

  test "loading a user with a blank fisherman_status leaves the record unchanged" do
    user = create(:user)
    user.update_column(:fisherman_status, nil) # rubocop:disable Rails/SkipsModelValidations

    assert_not_predicate User.find(user.id), :changed?
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

  test "has_fisherman_owner_role remains true for revoked historical owner" do
    assert_predicate owner_user("revoked"), :has_fisherman_owner_role?
  end

  test "a provisioned owner occupies the owner slot before claiming it" do
    assert_predicate owner_user("claimable"), :occupies_fisherman_owner_slot?
  end

  test "owner slot occupancy uses explicit assignment statuses" do
    assert_predicate owner_user("active"), :occupies_fisherman_owner_slot?
    assert_predicate owner_user("suspended"), :occupies_fisherman_owner_slot?
    assert_not owner_user("revoked").occupies_fisherman_owner_slot?
  end

  test "current_fisherman_owner is true only for active owner authorization" do
    assert_predicate owner_user("active"), :current_fisherman_owner?
    assert_not owner_user("suspended").current_fisherman_owner?
  end

  test "FINS governed fisherman requires system role and Company Profiling source" do
    owner = owner_user("claimable")
    owner.provisioning_source = ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE

    assert_predicate owner, :fins_governed_fisherman?

    owner.provisioning_source = ::Fisherman::ProvisionUser::FISHERMAN_OWNER

    assert_not owner.fins_governed_fisherman?
  end

  private

  def owner_user(fisherman_status)
    company_profile = create(:company_profile)
    owner_role = create(:role, :fisherman, company_profile: company_profile, name: "Owner", is_default: true)
    attributes = { role: owner_role, company_profile: company_profile, ic_number: SecureRandom.hex(5),
                   registration_type: "Commercial", fisherman_status: fisherman_status }
    attributes.merge!(claimed_identity_attributes) if fisherman_status == "active"
    build(:user, attributes)
  end

  def claimed_identity_attributes
    timestamp = Time.current
    { claimed_at: timestamp, brunei_id_verified_at: timestamp }
  end
end

# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  brunei_id_verified_at      :datetime
#  claimed_at                 :datetime
#  contact_no                 :string
#  designation                :string
#  discarded_at               :datetime
#  doft_registration_no       :string
#  email                      :string           default(""), not null
#  encrypted_password         :string           default(""), not null
#  fisherman_status           :string
#  ic_number                  :string
#  jti                        :string           not null
#  name                       :string           not null
#  normalized_ic_number       :string
#  position                   :string
#  preferred_locale           :string           default("en"), not null
#  provisioning_source        :string
#  registration_type          :string
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
#  created_by_id              :uuid
#  employee_id                :string
#  role_id                    :uuid
#
# Indexes
#
#  index_users_on_company_profile_contact_id              (company_profile_contact_id)
#  index_users_on_company_profile_contact_id_kept_unique  (company_profile_contact_id) UNIQUE WHERE ((company_profile_contact_id IS NOT NULL) AND (discarded_at IS NULL))
#  index_users_on_company_profile_id                      (company_profile_id)
#  index_users_on_discarded_at                            (discarded_at)
#  index_users_on_email                                   (email) UNIQUE WHERE ((email)::text <> ''::text)
#  index_users_on_employee_id                             (employee_id) UNIQUE
#  index_users_on_ic_number                               (ic_number)
#  index_users_on_jti                                     (jti) UNIQUE
#  index_users_on_normalized_ic_number_kept_unique        (normalized_ic_number) UNIQUE WHERE ((normalized_ic_number IS NOT NULL) AND (discarded_at IS NULL))
#  index_users_on_reset_password_token                    (reset_password_token) UNIQUE
#  index_users_on_role_id                                 (role_id)
#  index_users_on_username                                (username) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (company_profile_contact_id => company_profile_contacts.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (role_id => roles.id)
#
