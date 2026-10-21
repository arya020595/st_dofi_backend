class ManifestSkipReason < ApplicationRecord
  include Discard::Model

  validates :name, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
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
