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
