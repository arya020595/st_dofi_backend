FactoryBot.define do
  factory :permission do
    sequence(:code) { |n| "resource_#{n}.view" }
    name { "Resource - View" }
  end
end

# == Schema Information
#
# Table name: permissions
# Database name: primary
#
#  id         :uuid             not null, primary key
#  code       :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_permissions_on_code  (code) UNIQUE
#
