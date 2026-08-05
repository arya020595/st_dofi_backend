FactoryBot.define do
  factory :companies_vessel do
    company_profile
    sequence(:vessel_name) { |n| "Vessel #{n}" }
    sequence(:boat_number) { |n| "BN #{1000 + n}" }

    trait :approved do
      approval_status { "approved" }
    end

    trait :non_powered do
      is_powered { false }
    end

    trait :temporary do
      boat_type { "temporary" }
    end
  end
end

# == Schema Information
#
# Table name: companies_vessels
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  amendment_remarks   :text
#  approval_status     :string           default("pending"), not null
#  approved_at         :datetime
#  boat_number         :string           not null
#  boat_type           :string           default("permanent"), not null
#  capacity            :integer
#  category            :string
#  charter_type        :string
#  discarded_at        :datetime
#  draft               :decimal(10, 2)
#  engine_count        :integer
#  gross_tonnage       :decimal(10, 2)
#  horse_power         :decimal(10, 2)
#  is_powered          :boolean          default(TRUE), not null
#  length              :decimal(10, 2)
#  license_expiry_date :date
#  license_reg_date    :date
#  material            :string
#  max_crew            :integer
#  registration_no     :string
#  status              :string           default("active"), not null
#  vessel_name         :string           not null
#  year_built          :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  approved_by_id      :uuid
#  company_profile_id  :uuid             not null
#  zone_id             :uuid
#
# Indexes
#
#  index_companies_vessels_on_approval_status     (approval_status)
#  index_companies_vessels_on_approved_by_id      (approved_by_id)
#  index_companies_vessels_on_boat_number         (boat_number)
#  index_companies_vessels_on_company_profile_id  (company_profile_id)
#  index_companies_vessels_on_discarded_at        (discarded_at)
#  index_companies_vessels_on_registration_no     (registration_no)
#  index_companies_vessels_on_status              (status)
#  index_companies_vessels_on_zone_id             (zone_id)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (zone_id => zones.id)
#
