FactoryBot.define do
  factory :role do
    sequence(:reference_id) { |n| "ROLE-TEST-#{n}" }
    sequence(:name) { |n| "Test Role #{n}" }
    description { "A test role" }
  end
end
