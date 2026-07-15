FactoryBot.define do
  factory :companies_crew do
    company_profile
    sequence(:crew_name) { |n| "Crew Member #{n}" }

    trait :approved do
      approval_status { "approved" }
    end
  end
end
