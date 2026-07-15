FactoryBot.define do
  factory :manifest_minor_fisherman do
    manifest
    sequence(:full_name) { |n| "Minor Fisherman #{n}" }
    date_of_birth { 10.years.ago.to_date }
    gender { "male" }
    relationship_with_owner { "Son" }
  end
end
