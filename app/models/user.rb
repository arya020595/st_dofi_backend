class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher
  include Discard::Model

  devise :database_authenticatable, :jwt_authenticatable, :validatable,
         jwt_revocation_strategy: self

  belongs_to :role, optional: true
  belongs_to :company_profile, optional: true

  include AASM

  VALID_LOCALES = %w[en ms].freeze
  VALID_REGISTRATION_TYPES = ["Commercial", "Small-Scale (Company)", "Small - Scale (Full-Time)"].freeze
  DOFI_OFFICER_ROLE_REFERENCE_ID = "ROLE-001".freeze
  JETTY_MANAGER_ROLE_REFERENCE_ID = "ROLE-002".freeze
  FISHERMAN_ROLE_REFERENCE_ID = "ROLE-003".freeze
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

  validates :name, presence: true
  validates :preferred_locale, inclusion: { in: VALID_LOCALES }
  validates :ic_number, uniqueness: true, allow_nil: true
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

  def jetty_manager? = role&.reference_id == JETTY_MANAGER_ROLE_REFERENCE_ID
  def fisherman? = role&.reference_id == FISHERMAN_ROLE_REFERENCE_ID
  def officer? = role&.reference_id == DOFI_OFFICER_ROLE_REFERENCE_ID
  def approval_status_label = APPROVAL_STATUS_LABELS.fetch(status, status.humanize)

  # No role in this system requires a real email: DoFi Officers authenticate by `username`,
  # Fisherman/Jetty Manager via BruneiID QR re-scan (see Users::RegisterJettyManager,
  # Users::RegisterFisherman). `email` stays as an optional legacy/contact field (the seeded admin
  # still has one) but is never required; email_changed? still gates Devise's format/uniqueness
  # checks so a *provided* email is still validated when one is set.
  def email_required? = false
  def email_changed? = brunei_id_verified_at.blank? && super

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name email employee_id status preferred_locale unit position contact_no role_id doft_registration_no
       ic_number registration_type username discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
