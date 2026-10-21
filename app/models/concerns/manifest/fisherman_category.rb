module Manifest::FishermanCategory
  extend ActiveSupport::Concern

  COMMERCIAL = "commercial".freeze
  SMALL_SCALE = %w[small_scale_company small_scale_full_time small_scale_part_time].freeze

  def commercial?  = fisherman_category == COMMERCIAL
  def small_scale? = SMALL_SCALE.include?(fisherman_category)
end
