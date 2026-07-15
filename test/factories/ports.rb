FactoryBot.define do
  factory :port do
    sequence(:port_name) { |n| "Port #{n}" }
  end
end
