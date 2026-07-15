class CompanyProfile < ApplicationRecord
  include Discard::Model

  # A Small-Scale (Full-Time) profile is still officer-profiled via POST /api/v1/company_profiles
  # like any other type (see Users::RegisterFisherman) — it just represents one person rather than
  # a company, so it's profiled with only an Owner CompanyProfileContact (the fisherman themselves)
  # and no company-shape fields. Company-shape fields (company_name, worker_quota, district,
  # fisherman_card_no, ...) stay optional for this type rather than validating for data that path
  # doesn't collect — see CLAUDE.md "don't validate for scenarios that can't happen."
  INDIVIDUAL_REGISTRATION_TYPES = ["Small - Scale (Full-Time)"].freeze

  belongs_to :approved_by_user, class_name: "User", foreign_key: "approved_by", inverse_of: false, optional: true
  has_many :users, dependent: :nullify
  has_many :contacts, class_name: "CompanyProfileContact", dependent: :restrict_with_error
  has_many :companies_vessels, dependent: :restrict_with_error
  has_many :companies_crews, dependent: :restrict_with_error
  has_many :companies_captains, dependent: :restrict_with_error
  has_many :companies_fishing_gears, dependent: :restrict_with_error
  has_many :manifests, dependent: :restrict_with_error

  validates :registration_type, presence: true
  validates :company_name, :company_address, :contact_no, :district, :mukim, :village,
            :fisherman_card_no, :issue_date, :license_expiry_date, :worker_quota,
            presence: true, unless: :individual?

  def individual? = INDIVIDUAL_REGISTRATION_TYPES.include?(registration_type)

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
