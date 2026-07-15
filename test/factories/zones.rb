FactoryBot.define do
  factory :zone do
    sequence(:name) { |n| "Zone #{n}" }
    start_range { "0 nm" }
    end_range { "12 nm" }
  end
end
