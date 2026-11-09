module Manifest::FishermanCategory
  extend ActiveSupport::Concern

  COMMERCIAL = "commercial".freeze
  SMALL_SCALE_COMPANY = "small_scale_company".freeze
  SMALL_SCALE = [SMALL_SCALE_COMPANY, "small_scale_full_time", "small_scale_part_time"].freeze

  def commercial?  = fisherman_category == COMMERCIAL
  def small_scale? = SMALL_SCALE.include?(fisherman_category)
end
