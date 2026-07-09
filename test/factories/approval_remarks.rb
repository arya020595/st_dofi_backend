FactoryBot.define do
  factory :approval_remark do
    sequence(:name) { |n| "Test Remark #{n}" }
  end
end
