FactoryBot.define do
  factory :companies_captain do
    company_profile
    sequence(:captain_name) { |n| "Captain #{n}" }

    trait :approved do
      approval_status { "approved" }
    end
  end
end
