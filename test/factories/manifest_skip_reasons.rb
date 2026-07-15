FactoryBot.define do
  factory :manifest_skip_reason do
    sequence(:name) { |n| "Skip Reason #{n}" }
  end
end
