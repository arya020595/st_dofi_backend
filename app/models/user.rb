class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher
  include Discard::Model

  devise :database_authenticatable, :jwt_authenticatable, :validatable,
         jwt_revocation_strategy: self

  belongs_to :role, optional: true
  belongs_to :company_profile, optional: true
  belongs_to :company_profile_contact, optional: true
  belongs_to :approved_by, class_name: "User", optional: true, inverse_of: false
  belongs_to :created_by, class_name: "User", optional: true, inverse_of: false
  belongs_to :revoked_by, class_name: "User", optional: true, inverse_of: false
  belongs_to :revocation_remark, class_name: "ApprovalRemark", optional: true, inverse_of: false
  has_many :notifications, dependent: :delete_all

  include AASM
  include User::FishermanLifecycle

  audited only: %i[
    name ic_number normalized_ic_number status fisherman_status provisioning_source claimed_at
    brunei_id_verified_at approved_at approved_by_id created_by_id company_profile_id
    company_profile_contact_id role_id rejection_reason revoked_at revoked_by_id revocation_remark_id
    revocation_comment discarded_at
  ]

  VALID_LOCALES = %w[en ms].freeze
  VALID_REGISTRATION_TYPES = ["Commercial", "Small-Scale (Company)", "Small - Scale (Full-Time)",
                              "Small - Scale (Part-Time)"].freeze
  USERNAME_PREFIX = "MPRT".freeze

  aasm column: :status do
    state :active, initial: true
    state :inactive
    state :suspended
    state :pending
    state :rejected

    event :approve do
      transitions from: :pending, to: :active
    end

    event :reject do
      transitions from: :pending, to: :rejected
    end

    event :deactivate do
      transitions from: %i[active suspended], to: :inactive
    end

    event :suspend do
      transitions from: %i[active inactive], to: :suspended
    end

    event :reactivate do
      transitions from: %i[inactive suspended], to: :active
    end
  end

  APPROVAL_STATUS_LABELS = { "pending" => "Pending", "active" => "Approved", "rejected" => "Rejected",
                             "inactive" => "Approved", "suspended" => "Approved" }.freeze

  before_validation :normalize_ic_number

  validates :name, presence: true
  validates :preferred_locale, inclusion: { in: VALID_LOCALES }
  validates :normalized_ic_number, uniqueness: { conditions: -> { where(discarded_at: nil) } }, allow_nil: true
  validates :employee_id, uniqueness: true, allow_nil: true
  validates :username, uniqueness: true, allow_nil: true
  validates :ic_number, :unit, :position, :contact_no, presence: true, if: :jetty_manager?
  validates :ic_number, presence: true, if: :fisherman?
  validates :registration_type, inclusion: { in: VALID_REGISTRATION_TYPES }, if: :fisherman?
  validates :position, :unit, :username, presence: true, if: :officer?

  def permission?(*codes)
    return false unless role

    role.permissions.exists?(code: codes)
  end

  # officer?/jetty_manager? stay narrow (kind-based) — "is this literally the one canonical
  # singleton row." fisherman?/dofi_officer_platform? are broad (platform_scope-based) — "is this
  # user's role anywhere on this platform," true for every company's Owner/custom role too, not just
  # a single fixed row. See Role's own kind vs platform_scope comment for the full rationale.
  def jetty_manager? = role&.kind == Role::JETTY_MANAGER
  def officer? = role&.kind == Role::DOFI_OFFICER
  def fisherman? = role&.fisherman_platform? || false
  def dofi_officer_platform? = role&.dofi_officer_platform? || false
  def fins_governed_jetty_manager? = kept? && jetty_manager?
  def approval_status_label = APPROVAL_STATUS_LABELS.fetch(status, status.humanize)

  def fisherman_approval_status_label
    Users::FishermanApprovalStatusLabel.call(fisherman_status)
  end

  def lifecycle_status
    fisherman? && fisherman_status.present? ? fisherman_status : status
  end

  # No role in this system requires a real email: DoFi Officers authenticate by `username`,
  # Fisherman/Jetty Manager via BruneiID QR re-scan. `email` stays as an optional legacy/contact
  # field (the seeded admin
  # still has one) but is never required; email_changed? still gates Devise's format/uniqueness
  # checks so a *provided* email is still validated when one is set.
  def email_required? = false
  def email_changed? = brunei_id_verified_at.blank? && super

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name email employee_id status fisherman_status normalized_ic_number preferred_locale unit position contact_no
       role_id doft_registration_no ic_number registration_type username revoked_at revoked_by_id
       revocation_remark_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def normalize_ic_number
    self.normalized_ic_number = IcNumbers::Normalize.call(ic_number).presence if will_save_change_to_ic_number?
  end
end

# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  approved_at                :datetime
#  brunei_id_verified_at      :datetime
#  claimed_at                 :datetime
#  contact_no                 :string
#  designation                :string
#  discarded_at               :datetime
#  doft_registration_no       :string
#  email                      :string           default(""), not null
#  encrypted_password         :string           default(""), not null
#  fisherman_status           :string
#  ic_number                  :string
#  jti                        :string           not null
#  name                       :string           not null
#  normalized_ic_number       :string
#  position                   :string
#  preferred_locale           :string           default("en"), not null
#  provisioning_source        :string
#  registration_type          :string
#  rejection_reason           :text
#  remember_created_at        :datetime
#  reset_password_sent_at     :datetime
#  reset_password_token       :string
#  revocation_comment         :text
#  revoked_at                 :datetime
#  status                     :string           default("active"), not null
#  unit                       :string
#  username                   :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  approved_by_id             :uuid
#  company_profile_contact_id :uuid
#  company_profile_id         :uuid
#  created_by_id              :uuid
#  employee_id                :string
#  revocation_remark_id       :uuid
#  revoked_by_id              :uuid
#  role_id                    :uuid
#
# Indexes
#
#  index_users_on_company_profile_contact_id              (company_profile_contact_id)
#  index_users_on_company_profile_contact_id_kept_unique  (company_profile_contact_id)
#                                                          UNIQUE WHERE
#                                                          ((company_profile_contact_id IS NOT NULL) AND
#                                                          (discarded_at IS NULL))
#  index_users_on_company_profile_id                      (company_profile_id)
#  index_users_on_discarded_at                            (discarded_at)
#  index_users_on_email                                   (email) UNIQUE WHERE ((email)::text <> ''::text)
#  index_users_on_employee_id                             (employee_id) UNIQUE
#  index_users_on_ic_number                               (ic_number)
#  index_users_on_jti                                     (jti) UNIQUE
#  index_users_on_normalized_ic_number_kept_unique        (normalized_ic_number)
#                                                          UNIQUE WHERE
#                                                          ((normalized_ic_number IS NOT NULL) AND
#                                                          (discarded_at IS NULL))
#  index_users_on_reset_password_token                    (reset_password_token) UNIQUE
#  index_users_on_revocation_remark_id                    (revocation_remark_id)
#  index_users_on_revoked_by_id                           (revoked_by_id)
#  index_users_on_role_id                                 (role_id)
#  index_users_on_username                                (username) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_contact_id => company_profile_contacts.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (revocation_remark_id => approval_remarks.id)
#  fk_rails_...  (revoked_by_id => users.id)
#  fk_rails_...  (role_id => roles.id)
#
