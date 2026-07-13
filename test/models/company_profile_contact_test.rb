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
