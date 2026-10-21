FactoryBot.define do
  factory :fishing_gear_detail do
    capture_report
    sequence(:name) { |n| "Gear #{n}" }
    gear_type { "Net" }
    quantity { 1 }
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
