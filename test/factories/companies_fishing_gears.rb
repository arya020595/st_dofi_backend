FactoryBot.define do
  factory :companies_fishing_gear do
    company_profile
    companies_vessel { association(:companies_vessel, company_profile: company_profile) }
    fishing_gear
    quantity { 1 }

    trait :approved do
      approval_status { "approved" }
    end
  end
end

# == Schema Information
#
# Table name: companies_fishing_gears
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  amendment_remarks   :text
#  approval_status     :string           default("pending"), not null
#  approved_at         :datetime
#  discarded_at        :datetime
#  fishing_gear_fee    :decimal(10, 2)
#  fishing_gear_name   :string
#  fishing_gear_type   :string
#  local_name          :string
#  quantity            :integer
#  usage_value         :decimal(10, 2)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  approved_by_id      :uuid
#  companies_vessel_id :uuid
#  company_profile_id  :uuid             not null
#  fishing_gear_id     :uuid             not null
#
# Indexes
#
#  index_companies_fishing_gears_on_approval_status      (approval_status)
#  index_companies_fishing_gears_on_approved_by_id       (approved_by_id)
#  index_companies_fishing_gears_on_companies_vessel_id  (companies_vessel_id)
#  index_companies_fishing_gears_on_company_profile_id   (company_profile_id)
#  index_companies_fishing_gears_on_discarded_at         (discarded_at)
#  index_companies_fishing_gears_on_fishing_gear_id      (fishing_gear_id)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (companies_vessel_id => companies_vessels.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (fishing_gear_id => fishing_gears.id)
#
