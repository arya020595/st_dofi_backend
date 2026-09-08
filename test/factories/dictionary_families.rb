FactoryBot.define do
  factory :dictionary_family do
    dictionary_group
    sequence(:name) { |n| "Fish Family #{n}" }
  end
end

# == Schema Information
#
# Table name: dictionary_families
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  name                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  dictionary_group_id :uuid             not null
#
# Indexes
#
#  index_dictionary_families_on_dictionary_group_id           (dictionary_group_id)
#  index_dictionary_families_on_dictionary_group_id_and_name  (dictionary_group_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (dictionary_group_id => dictionary_groups.id)
#
