FactoryBot.define do
  factory :dictionary do
    sequence(:local_name) { |n| "Ikan #{n}" }
    scientific_name { "Species scientificus" }
  end
end

# == Schema Information
#
# Table name: dictionaries
# Database name: primary
#
#  id              :uuid             not null, primary key
#  family_name     :string
#  group_name      :string
#  local_name      :string           not null
#  scientific_name :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  idx_dictionaries_local_name_trgm       (local_name) USING gin
#  idx_dictionaries_scientific_name_trgm  (scientific_name) USING gin
#  index_dictionaries_on_local_name       (local_name)
#
