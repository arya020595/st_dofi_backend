FactoryBot.define do
  factory :approval_remark do
    sequence(:reference_id) { |n| "AR-TEST-#{n}" }
    sequence(:name) { |n| "Test Remark #{n}" }
  end
end
