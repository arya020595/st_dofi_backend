FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    sequence(:employee_id) { |n| "EMP-#{n}" }
    sequence(:username) { |n| "user#{n}" }
    password { "Password123!" }
    password_confirmation { "Password123!" }
    status { "active" }
    preferred_locale { "en" }
    role
  end
end
