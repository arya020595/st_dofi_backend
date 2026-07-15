FactoryBot.define do
  factory :companies_vessel do
    company_profile
    sequence(:vessel_name) { |n| "Vessel #{n}" }
    sequence(:boat_number) { |n| "BN #{1000 + n}" }

    trait :approved do
      approval_status { "approved" }
    end
  end
end
