class DictionaryFamily < ApplicationRecord
  belongs_to :dictionary_group
  has_many :dictionaries, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :dictionary_group_id }
  validate :group_change_requires_no_species

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name dictionary_group_id created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[dictionary_group]
  end

  private

  def group_change_requires_no_species
    return unless will_save_change_to_dictionary_group_id?
    return unless dictionaries.exists?

    errors.add(:dictionary_group, "cannot change while the family is used by species")
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
