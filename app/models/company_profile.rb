class CompanyProfile < ApplicationRecord
  include Discard::Model

  belongs_to :approved_by_user, class_name: "User", foreign_key: "approved_by", inverse_of: false, optional: true
  has_many :users, dependent: :nullify
  has_many :contacts, class_name: "CompanyProfileContact", dependent: :restrict_with_error

  validates :registration_type, :company_name, :company_address, :contact_no, :district, :mukim, :village,
            :fisherman_card_no, :issue_date, :license_expiry_date, :worker_quota, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id dofi_registration_no registration_type company_name rocbn_no
       approval_status discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[contacts]
  end

  def owner_contact = contacts.kept.find_by(designation: "Owner")
  def admin_contact = contacts.kept.find_by(designation: "Admin")
end
