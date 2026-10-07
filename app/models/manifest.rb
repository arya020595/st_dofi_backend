class Manifest < ApplicationRecord
  include Discard::Model
  include AASM
  include HasManifestHistory
  include Manifest::FishermanCategory
  include Manifest::CaptureReportState
  include Manifest::PortOutWorkflow
  include Manifest::PortInWorkflow
  include Manifest::StatusWorkflow

  belongs_to :companies_vessel
  belongs_to :captain_crew, class_name: "CompaniesCrew", optional: true
  belongs_to :support_vessel, class_name: "CompaniesVessel", optional: true
  belongs_to :company_profile
  belongs_to :port_out, class_name: "Port", optional: true
  belongs_to :port_in, class_name: "Port", optional: true
  belongs_to :zone, optional: true
  belongs_to :skip_reason, class_name: "ManifestSkipReason", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :crew_manifests, dependent: :restrict_with_error
  has_many :manifest_support_vessels, dependent: :restrict_with_error
  has_many :support_vessels, through: :manifest_support_vessels, source: :companies_vessel
  has_many :manifest_minor_fishermen, dependent: :restrict_with_error
  has_many :capture_reports, dependent: :restrict_with_error
  has_many :manifest_histories, dependent: :restrict_with_error
  has_one :manifest_expense, dependent: :restrict_with_error

  validates :manifest_number, presence: true, uniqueness: true
  validates :fisherman_category, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id manifest_number fisherman_category manifest_status port_out_status port_in_status
       vessel_boat_name vessel_boat_no company_name capture_report_skipped has_minor_fishermen
       company_profile_id companies_vessel_id captain_crew_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def manifest_id_for_history = id
end

# == Schema Information
#
# Table name: manifests
# Database name: primary
#
#  id                               :uuid             not null, primary key
#  ais_tracking                     :boolean          default(FALSE), not null
#  captain_ic_number                :string
#  captain_name                     :string
#  capture_report_amendment_remarks :text
#  capture_report_skipped           :boolean          default(FALSE), not null
#  company_name                     :string
#  discarded_at                     :datetime
#  fisherman_category               :string           not null
#  has_minor_fishermen              :boolean          default(FALSE), not null
#  has_support_vessel               :boolean          default(FALSE), not null
#  latitude                         :decimal(10, 8)
#  longitude                        :decimal(11, 8)
#  manifest_number                  :string           not null
#  manifest_status                  :string           default("draft"), not null
#  port_in_amendment_remarks        :text
#  port_in_area                     :string
#  port_in_datetime                 :datetime
#  port_in_name                     :string
#  port_in_status                   :string           default("draft"), not null
#  port_out_amendment_remarks       :text
#  port_out_area                    :string
#  port_out_datetime                :datetime
#  port_out_name                    :string
#  port_out_status                  :string           default("draft"), not null
#  skip_reason_name                 :string
#  skip_reason_remarks              :text
#  support_vessel_name              :string
#  support_vessel_no                :string
#  vessel_boat_name                 :string
#  vessel_boat_no                   :string
#  zone_area                        :string
#  zone_name                        :string
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  captain_crew_id                  :uuid
#  companies_vessel_id              :uuid             not null
#  company_profile_id               :uuid             not null
#  created_by_id                    :uuid
#  port_in_id                       :uuid
#  port_out_id                      :uuid
#  skip_reason_id                   :uuid
#  support_vessel_id                :uuid
#  zone_id                          :uuid
#
# Indexes
#
#  index_manifests_on_captain_crew_id         (captain_crew_id)
#  index_manifests_on_capture_report_skipped  (capture_report_skipped)
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
#  fk_rails_...  (captain_crew_id => companies_crews.id)
#  fk_rails_...  (companies_vessel_id => companies_vessels.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (port_in_id => ports.id)
#  fk_rails_...  (port_out_id => ports.id)
#  fk_rails_...  (skip_reason_id => manifest_skip_reasons.id)
#  fk_rails_...  (support_vessel_id => companies_vessels.id)
#  fk_rails_...  (zone_id => zones.id)
#
