FactoryBot.define do
  factory :crew_manifest do
    manifest
    sequence(:crew_name) { |n| "Crew #{n}" }
  end
end
