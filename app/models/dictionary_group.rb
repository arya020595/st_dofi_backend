class DictionaryGroup < ApplicationRecord
  has_many :dictionary_families, dependent: :restrict_with_error
  has_many :dictionaries, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
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
