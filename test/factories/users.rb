FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    sequence(:employee_id) { |n| "EMP-#{n}" }
    password { "Password123!" }
    password_confirmation { "Password123!" }
    status { "active" }
    preferred_locale { "en" }
    role
  end
end
