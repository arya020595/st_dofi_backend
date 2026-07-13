require "test_helper"
class CompanyProfileTest < ActiveSupport::TestCase
  test "invalid without worker_quota" do
    profile = build(:company_profile, worker_quota: nil)
    profile.valid?

    assert_includes profile.errors.attribute_names, :worker_quota
  end

  test "owner_contact and admin_contact find the kept contact with the matching designation" do
    company_profile = create(:company_profile)
    owner = create(:company_profile_contact, company_profile: company_profile, designation: "Owner")
    admin = create(:company_profile_contact, company_profile: company_profile, designation: "Admin")

    assert_equal owner, company_profile.owner_contact
    assert_equal admin, company_profile.admin_contact
  end

  test "owner_contact ignores discarded contacts" do
    company_profile = create(:company_profile)
    owner = create(:company_profile_contact, company_profile: company_profile, designation: "Owner")
    owner.discard

    assert_nil company_profile.owner_contact
  end

  test "admin_contact is nil when the company has no admin" do
    company_profile = create(:company_profile)
    create(:company_profile_contact, company_profile: company_profile, designation: "Owner")

    assert_nil company_profile.admin_contact
  end
end

# == Schema Information
#
# Table name: company_profiles
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  amendment_remarks    :text
#  approval_status      :string           default("pending"), not null
#  approved_at          :datetime
#  approved_by          :uuid
#  company_address      :text
#  company_name         :string
#  contact_no           :string
#  date_approval        :date
#  designation          :string
#  discarded_at         :datetime
#  district             :string
#  dofi_registration_no :string
#  fisherman_card_no    :string
#  full_address         :string
#  full_name            :string
#  gender               :string
#  ic_colour            :string
#  ic_no                :string
#  issue_date           :date
#  license_expiry_date  :date
#  logo_url             :string
#  mukim                :string
#  registration_type    :string           not null
#  rocbn_no             :string
#  village              :string
#  worker_quota         :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_company_profiles_on_approval_status  (approval_status)
#  index_company_profiles_on_approved_by      (approved_by)
#  index_company_profiles_on_discarded_at     (discarded_at)
#  index_company_profiles_on_ic_no            (ic_no)
#  index_company_profiles_on_rocbn_no         (rocbn_no)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by => users.id)
#
