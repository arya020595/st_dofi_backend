FactoryBot.define do
  factory :fishing_gear do
    sequence(:local_name) { |n| "Pukat #{n}" }
    sequence(:name) { |n| "Gear #{n}" }
    gear_type { "Net" }
    fee { 10.0 }
  end
end
