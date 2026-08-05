FactoryBot.define do
  factory :position do
    sequence(:name) { |n| "Position #{n}" }
    category { "Crew" }
  end
end

# == Schema Information
#
# Table name: positions
# Database name: primary
#
#  id         :uuid             not null, primary key
#  category   :string
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_positions_on_name  (name) UNIQUE
#
