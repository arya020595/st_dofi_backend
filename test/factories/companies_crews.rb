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
