FactoryBot.define do
  factory :fishing_gear_detail do
    capture_report
    sequence(:name) { |n| "Gear #{n}" }
    gear_type { "Net" }
    quantity { 1 }
  end
end
