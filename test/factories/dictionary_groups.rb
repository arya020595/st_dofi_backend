FactoryBot.define do
  factory :dictionary_group do
    sequence(:name) { |n| "Fish Group #{n}" }
  end
end

# == Schema Information
#
# Table name: dictionary_groups
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_dictionary_groups_on_name  (name) UNIQUE
#
