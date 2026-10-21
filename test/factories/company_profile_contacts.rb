FactoryBot.define do
  factory :company_profile_contact do
    company_profile
    full_name { "Muhammad Shahrizan Bin Haji Said" }
    gender { "Male" }
    ic_colour { "Yellow" }
    designation { "Owner" }
    sequence(:ic_no) { |n| format("01-%06d", n) }
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
