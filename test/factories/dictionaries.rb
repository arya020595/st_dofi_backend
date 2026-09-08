FactoryBot.define do
  factory :dictionary do
    dictionary_group
    dictionary_family { association :dictionary_family, dictionary_group: }
    sequence(:local_name) { |n| "Ikan #{n}" }
    scientific_name { "Species scientificus" }
  end
end

# == Schema Information
#
# Table name: dictionaries
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  local_name           :string           not null
#  scientific_name      :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  dictionary_family_id :uuid             not null
#  dictionary_group_id  :uuid             not null
#
# Indexes
#
#  idx_dictionaries_local_name_trgm            (local_name) USING gin
#  idx_dictionaries_scientific_name_trgm       (scientific_name) USING gin
#  index_dictionaries_on_dictionary_family_id  (dictionary_family_id)
#  index_dictionaries_on_dictionary_group_id   (dictionary_group_id)
#  index_dictionaries_on_local_name            (local_name)
#
# Foreign Keys
#
#  fk_rails_...  (dictionary_family_id => dictionary_families.id)
#  fk_rails_...  (dictionary_group_id => dictionary_groups.id)
#
