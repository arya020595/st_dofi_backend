FactoryBot.define do
  factory :zone do
    sequence(:name) { |n| "Zone #{n}" }
    start_range { 0 }
    end_range { 12 }
  end
end

# == Schema Information
#
# Table name: zones
# Database name: primary
#
#  id           :uuid             not null, primary key
#  discarded_at :datetime
#  end_range    :integer
#  name         :string           not null
#  start_range  :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_zones_on_discarded_at  (discarded_at)
#
