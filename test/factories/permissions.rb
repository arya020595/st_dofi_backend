FactoryBot.define do
  factory :permission do
    sequence(:code) { |n| "resource_#{n}.view" }
    name { "Resource - View" }
  end
end
