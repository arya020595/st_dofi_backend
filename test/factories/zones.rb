FactoryBot.define do
  factory :zone do
    sequence(:name) { |n| "Zone #{n}" }
    start_range { "0 nm" }
    end_range { "12 nm" }
  end
end

# == Schema Information
#
# Table name: zones
# Database name: primary
#
#  id          :uuid             not null, primary key
#  end_range   :string
#  name        :string           not null
#  start_range :string
#  zone_type   :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
