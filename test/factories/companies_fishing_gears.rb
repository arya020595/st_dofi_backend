FactoryBot.define do
  factory :companies_fishing_gear do
    company_profile
    fishing_gear
    companies_vessel { association :companies_vessel, company_profile: company_profile }
    quantity { 1 }

    trait :approved do
      approval_status { "approved" }
    end
  end
end
