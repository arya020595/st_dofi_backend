class Dictionary < ApplicationRecord
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 5.megabytes

  # Public-read bucket (see docs/minio/MINIO.md §2) — fish-species reference photos are not sensitive,
  # so downloads bypass Rails entirely rather than going through the private redirect pattern.
  has_one_attached :image, service: Rails.application.config.x.active_storage_public_service

  belongs_to :dictionary_group
  belongs_to :dictionary_family

  validates :local_name, presence: true
  validate :family_belongs_to_group
  validate :image_content_type_and_size, if: -> { image.attached? }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id local_name scientific_name dictionary_group_id dictionary_family_id created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[dictionary_family dictionary_group]
  end

  private

  def image_content_type_and_size
    errors.add(:image, "must be a JPEG, PNG, or WebP") unless ALLOWED_IMAGE_TYPES.include?(image.content_type)
    errors.add(:image, "must be smaller than 5 MB") if image.byte_size > MAX_IMAGE_SIZE
  end

  def family_belongs_to_group
    return if dictionary_family.blank? || dictionary_group.blank?
    return if dictionary_family.dictionary_group_id == dictionary_group_id

    errors.add(:dictionary_family, "must belong to the selected dictionary group")
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
