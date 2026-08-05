FactoryBot.define do
  factory :companies_crew do
    company_profile
    sequence(:crew_name) { |n| "Crew Member #{n}" }
    date_of_birth { Date.new(1990, 1, 1) }
    sequence(:ic_number) { |n| format("%08d", 10_000_000 + n) }
    nationality { "Bruneian" }
    position { "Deckhand" }
    gender { "Male" }
    sequence(:foreign_worker_license_no) { |n| "FWL#{format('%06d', n)}" }
    foreign_worker_license_start_date { Date.new(2026, 1, 1) }
    foreign_worker_license_end_date { Date.new(2027, 1, 1) }

    trait :approved do
      approval_status { "approved" }
    end

    trait :non_active do
      status { "non_active" }
    end
  end
end

# == Schema Information
#
# Table name: companies_crews
# Database name: primary
#
#  id                                :uuid             not null, primary key
#  amendment_remarks                 :text
#  approval_status                   :string           default("pending"), not null
#  approved_at                       :datetime
#  crew_name                         :string           not null
#  date_of_birth                     :date
#  discarded_at                      :datetime
#  foreign_worker_license_end_date   :date
#  foreign_worker_license_no         :string
#  foreign_worker_license_start_date :date
#  gender                            :string
#  ic_number                         :string
#  nationality                       :string
#  passport_number                   :string
#  position                          :string
#  status                            :string           default("active"), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  approved_by_id                    :uuid
#  company_profile_id                :uuid             not null
#
# Indexes
#
#  index_companies_crews_on_approval_status     (approval_status)
#  index_companies_crews_on_approved_by_id      (approved_by_id)
#  index_companies_crews_on_company_profile_id  (company_profile_id)
#  index_companies_crews_on_discarded_at        (discarded_at)
#  index_companies_crews_on_status              (status)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
