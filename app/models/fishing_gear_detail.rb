class FishingGearDetail < ApplicationRecord
  belongs_to :capture_report
  belongs_to :companies_fishing_gear, optional: true
  has_many :fish_capture_details, dependent: :destroy

  def self.ransackable_attributes(_auth_object = nil)
    %w[id capture_report_id companies_fishing_gear_id name gear_type specification quantity created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: fishing_gear_details
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  gear_type                 :string
#  name                      :string
#  quantity                  :integer
#  specification             :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  capture_report_id         :uuid             not null
#  companies_fishing_gear_id :uuid
#
# Indexes
#
#  index_fishing_gear_details_on_capture_report_id          (capture_report_id)
#  index_fishing_gear_details_on_companies_fishing_gear_id  (companies_fishing_gear_id)
#
# Foreign Keys
#
#  fk_rails_...  (capture_report_id => capture_reports.id)
#  fk_rails_...  (companies_fishing_gear_id => companies_fishing_gears.id)
#
