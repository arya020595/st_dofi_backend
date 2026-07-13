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

# == Schema Information
#
# Table name: company_profiles
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  amendment_remarks    :text
#  approval_status      :string           default("pending"), not null
#  approved_at          :datetime
#  approved_by          :uuid
#  company_address      :text
#  company_name         :string
#  contact_no           :string
#  date_approval        :date
#  designation          :string
#  discarded_at         :datetime
#  district             :string
#  dofi_registration_no :string
#  fisherman_card_no    :string
#  full_address         :string
#  full_name            :string
#  gender               :string
#  ic_colour            :string
#  ic_no                :string
#  issue_date           :date
#  license_expiry_date  :date
#  logo_url             :string
#  mukim                :string
#  registration_type    :string           not null
#  rocbn_no             :string
#  village              :string
#  worker_quota         :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_company_profiles_on_approval_status  (approval_status)
#  index_company_profiles_on_approved_by      (approved_by)
#  index_company_profiles_on_discarded_at     (discarded_at)
#  index_company_profiles_on_ic_no            (ic_no)
#  index_company_profiles_on_rocbn_no         (rocbn_no)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by => users.id)
#
