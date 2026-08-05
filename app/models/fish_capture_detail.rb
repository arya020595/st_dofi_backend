class FishCaptureDetail < ApplicationRecord
  belongs_to :capture_report
  belongs_to :dictionary
  belongs_to :fishing_gear_detail

  validates :amount_captured_kg, :price_per_kg, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id capture_report_id fishing_gear_detail_id dictionary_id local_name scientific_name fish_type price_per_kg
       amount_captured_kg overall_total synced_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: fish_capture_details
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  amount_captured_kg     :decimal(10, 3)
#  fish_type              :string
#  local_name             :string
#  overall_total          :decimal(12, 2)
#  price_per_kg           :decimal(10, 2)
#  scientific_name        :string
#  synced_at              :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  capture_report_id      :uuid             not null
#  dictionary_id          :uuid             not null
#  fishing_gear_detail_id :uuid
#
# Indexes
#
#  index_fish_capture_details_on_capture_report_id       (capture_report_id)
#  index_fish_capture_details_on_dictionary_id           (dictionary_id)
#  index_fish_capture_details_on_fishing_gear_detail_id  (fishing_gear_detail_id)
#
# Foreign Keys
#
#  fk_rails_...  (capture_report_id => capture_reports.id)
#  fk_rails_...  (dictionary_id => dictionaries.id)
#  fk_rails_...  (fishing_gear_detail_id => fishing_gear_details.id)
#
