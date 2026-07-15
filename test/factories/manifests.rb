FactoryBot.define do
  factory :manifest do
    company_profile
    companies_vessel { create(:companies_vessel, :approved, company_profile: company_profile) }
    fisherman_category { "commercial" }
    sequence(:manifest_number) { |n| "DOF-20260101-#{format('%03d', n)}" }

    trait :small_scale do
      fisherman_category { "small_scale_company" }
    end
  end
end
