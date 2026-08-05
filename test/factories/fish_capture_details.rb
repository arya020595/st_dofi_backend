FactoryBot.define do
  factory :fish_capture_detail do
    capture_report
    fishing_gear_detail { association(:fishing_gear_detail, capture_report: capture_report) }
    dictionary
    price_per_kg { 10.0 }
    amount_captured_kg { 5.0 }
    overall_total { 50.0 }
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
