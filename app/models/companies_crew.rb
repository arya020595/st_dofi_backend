class CompaniesCrew < ApplicationRecord
  include Discard::Model
  include Approvable

  STATUSES = %w[active non_active].freeze

  belongs_to :company_profile
  belongs_to :position, optional: true

  validates :crew_name, :date_of_birth, :ic_number, :nationality, :gender, presence: true
  validates :position, presence: true
  validates :foreign_worker_license_no, :foreign_worker_license_start_date, :foreign_worker_license_end_date,
            presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :position_must_be_crew_category

  def self.ransackable_attributes(_auth_object = nil)
    %w[id crew_name date_of_birth ic_number passport_number nationality gender status
       foreign_worker_license_no foreign_worker_license_start_date foreign_worker_license_end_date
       approval_status company_profile_id position_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[position]
  end

  private

  def position_must_be_crew_category
    return if position.nil? || position.category == "Crew"

    errors.add(:position, "must be a crew position")
  end
end

# == Schema Information
#
# Table name: companies_crews
# Database name: primary
#
#  id                                :uuid             not null, primary key
#  amendment_remarks                 :text
#  approval_status                   :string           default("pending"), not null
#  approved_at                       :datetime
#  crew_name                         :string           not null
#  date_of_birth                     :date
#  discarded_at                      :datetime
#  foreign_worker_license_end_date   :date
#  foreign_worker_license_no         :string
#  foreign_worker_license_start_date :date
#  gender                            :string
#  ic_number                         :string
#  nationality                       :string
#  passport_number                   :string
#  status                            :string           default("active"), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  approved_by_id                    :uuid
#  company_profile_id                :uuid             not null
#  position_id                       :uuid
#
# Indexes
#
#  index_companies_crews_on_approval_status     (approval_status)
#  index_companies_crews_on_approved_by_id      (approved_by_id)
#  index_companies_crews_on_company_profile_id  (company_profile_id)
#  index_companies_crews_on_discarded_at        (discarded_at)
#  index_companies_crews_on_position_id         (position_id)
#  index_companies_crews_on_status              (status)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (position_id => positions.id)
#
