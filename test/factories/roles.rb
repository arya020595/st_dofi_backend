FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "Test Role #{n}" }
    description { "A test role" }
  end
end
