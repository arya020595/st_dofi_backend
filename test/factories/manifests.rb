FactoryBot.define do
  factory :manifest do
    company_profile
    companies_vessel { create(:companies_vessel, :approved, company_profile: company_profile) }
    fisherman_category { "commercial" }
    sequence(:manifest_number) { |n| "DOF-20260101-#{format('%03d', n)}" }

    trait :small_scale do
      fisherman_category { "small_scale_company" }
    end
  end
end

# == Schema Information
#
# Table name: manifests
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  ais_tracking           :boolean          default(FALSE), not null
#  captain_ic_number      :string
#  captain_name           :string
#  capture_report_skipped :boolean          default(FALSE), not null
#  company_name           :string
#  discarded_at           :datetime
#  fisherman_category     :string           not null
#  has_minor_fishermen    :boolean          default(FALSE), not null
#  has_support_vessel     :boolean          default(FALSE), not null
#  latitude               :decimal(10, 8)
#  longitude              :decimal(11, 8)
#  manifest_number        :string           not null
#  manifest_status        :string           default("draft"), not null
#  port_in_area           :string
#  port_in_datetime       :datetime
#  port_in_status         :string           default("draft"), not null
#  port_out_area          :string
#  port_out_datetime      :datetime
#  port_out_status        :string           default("draft"), not null
#  skip_reason_remarks    :text
#  vessel_boat_name       :string
#  vessel_boat_no         :string
#  zone_area              :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  companies_captain_id   :uuid
#  companies_vessel_id    :uuid             not null
#  company_profile_id     :uuid             not null
#  created_by_id          :uuid
#  port_in_id             :uuid
#  port_out_id            :uuid
#  skip_reason_id         :uuid
#  support_vessel_id      :uuid
#  zone_id                :uuid
#
# Indexes
#
#  index_manifests_on_capture_report_skipped  (capture_report_skipped)
#  index_manifests_on_companies_captain_id    (companies_captain_id)
#  index_manifests_on_companies_vessel_id     (companies_vessel_id)
#  index_manifests_on_company_profile_id      (company_profile_id)
#  index_manifests_on_created_by_id           (created_by_id)
#  index_manifests_on_discarded_at            (discarded_at)
#  index_manifests_on_fisherman_category      (fisherman_category)
#  index_manifests_on_manifest_number         (manifest_number) UNIQUE
#  index_manifests_on_manifest_status         (manifest_status)
#  index_manifests_on_port_in_id              (port_in_id)
#  index_manifests_on_port_in_status          (port_in_status)
#  index_manifests_on_port_out_id             (port_out_id)
#  index_manifests_on_port_out_status         (port_out_status)
#  index_manifests_on_skip_reason_id          (skip_reason_id)
#  index_manifests_on_support_vessel_id       (support_vessel_id)
#  index_manifests_on_zone_id                 (zone_id)
#
# Foreign Keys
#
#  fk_rails_...  (companies_captain_id => companies_captains.id)
#  fk_rails_...  (companies_vessel_id => companies_vessels.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (port_in_id => ports.id)
#  fk_rails_...  (port_out_id => ports.id)
#  fk_rails_...  (skip_reason_id => manifest_skip_reasons.id)
#  fk_rails_...  (support_vessel_id => companies_vessels.id)
#  fk_rails_...  (zone_id => zones.id)
#
