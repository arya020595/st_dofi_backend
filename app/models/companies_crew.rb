class CompaniesCrew < ApplicationRecord
  include Discard::Model
  include Approvable

  STATUSES = %w[active non_active].freeze

  belongs_to :company_profile

  validates :crew_name, :date_of_birth, :ic_number, :nationality, :position, :gender, presence: true
  validates :foreign_worker_license_no, :foreign_worker_license_start_date, :foreign_worker_license_end_date,
            presence: true
  validates :status, inclusion: { in: STATUSES }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id crew_name date_of_birth ic_number passport_number position nationality gender status
       foreign_worker_license_no foreign_worker_license_start_date foreign_worker_license_end_date
       approval_status company_profile_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
