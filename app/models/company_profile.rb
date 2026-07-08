class CompanyProfile < ApplicationRecord
  include Discard::Model

  belongs_to :approved_by_user, class_name: "User", foreign_key: "approved_by", inverse_of: false, optional: true
  has_many :users, dependent: :nullify

  validates :reference_id, presence: true, uniqueness: true
  validates :registration_type, :company_name, :company_address, :contact_no, :district, :mukim, :village,
            :fisherman_card_no, :issue_date, :license_expiry_date, :worker_quota, presence: true
  validates :full_name, :ic_no, :gender, :ic_colour, :designation, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference_id dofi_registration_no registration_type company_name rocbn_no full_name ic_no
       approval_status discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def sibling
    return nil if rocbn_no.blank?

    CompanyProfile.kept.where(rocbn_no: rocbn_no, company_name: company_name).where.not(id: id).first
  end
end
