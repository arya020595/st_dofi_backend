require "test_helper"
class CompanyProfileContactTest < ActiveSupport::TestCase
  test "invalid without required person fields" do
    contact = build(:company_profile_contact, full_name: nil, ic_no: nil, gender: nil, ic_colour: nil,
                                              designation: nil)
    contact.valid?

    assert_equal %i[full_name ic_no gender ic_colour designation].sort, contact.errors.attribute_names.sort
  end

  test "belongs to a company_profile" do
    contact = create(:company_profile_contact)

    assert_instance_of CompanyProfile, contact.company_profile
  end

  test "discard soft-deletes the contact" do
    contact = create(:company_profile_contact)
    contact.discard

    assert_predicate contact, :discarded?
  end
end

# == Schema Information
#
# Table name: company_profile_contacts
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  designation        :string
#  discarded_at       :datetime
#  full_name          :string
#  gender             :string
#  ic_colour          :string
#  ic_no              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  company_profile_id :uuid             not null
#
# Indexes
#
#  index_company_profile_contacts_on_company_profile_id  (company_profile_id)
#  index_company_profile_contacts_on_discarded_at        (discarded_at)
#  index_company_profile_contacts_on_ic_no               (ic_no)
#
# Foreign Keys
#
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
