FactoryBot.define do
  factory :manifest_skip_reason do
    sequence(:name) { |n| "Skip Reason #{n}" }
  end
end

# == Schema Information
#
# Table name: manifest_skip_reasons
# Database name: primary
#
#  id           :uuid             not null, primary key
#  discarded_at :datetime
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_manifest_skip_reasons_on_discarded_at  (discarded_at)
#
