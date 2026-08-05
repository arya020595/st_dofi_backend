FactoryBot.define do
  factory :manifest_minor_fisherman do
    manifest
    sequence(:full_name) { |n| "Minor Fisherman #{n}" }
    date_of_birth { 10.years.ago.to_date }
    gender { "male" }
    relationship_with_owner { "Son" }
  end
end

# == Schema Information
#
# Table name: manifest_minor_fishermen
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  date_of_birth           :date             not null
#  full_name               :string           not null
#  gender                  :string           not null
#  relationship_with_owner :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  manifest_id             :uuid             not null
#
# Indexes
#
#  index_manifest_minor_fishermen_on_manifest_id  (manifest_id)
#
# Foreign Keys
#
#  fk_rails_...  (manifest_id => manifests.id)
#
