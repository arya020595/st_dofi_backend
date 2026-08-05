FactoryBot.define do
  factory :capture_report do
    manifest
  end
end

# == Schema Information
#
# Table name: capture_reports
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  capture_report_remarks :text
#  capture_report_status  :string           default("pending_verification"), not null
#  latitude               :decimal(10, 8)
#  longitude              :decimal(11, 8)
#  reviewed_at            :datetime
#  zone_area              :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  manifest_id            :uuid             not null
#  reviewed_by_id         :uuid
#  zone_id                :uuid
#
# Indexes
#
#  index_capture_reports_on_capture_report_status  (capture_report_status)
#  index_capture_reports_on_manifest_id            (manifest_id)
#  index_capture_reports_on_reviewed_by_id         (reviewed_by_id)
#  index_capture_reports_on_zone_id                (zone_id)
#
# Foreign Keys
#
#  fk_rails_...  (manifest_id => manifests.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (zone_id => zones.id)
#
