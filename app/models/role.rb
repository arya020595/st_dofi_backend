class Role < ApplicationRecord
  DOFI_OFFICER = "DoFi Officer".freeze
  JETTY_MANAGER = "Jetty Manager".freeze
  SYSTEM_KINDS = [DOFI_OFFICER, JETTY_MANAGER].freeze

  # `kind` (above) identifies the small, fixed set of canonical singleton roles that business logic
  # keys off directly (User#officer?/jetty_manager?) — nullable, globally unique, never client-writable.
  #
  # `platform_scope` (below) is a different, broader concept: which platform (Fisherman app vs DoFi
  # Officer dashboard) a role belongs to. Every role has one, including custom roles and the many
  # per-company Fisherman roles created via Roles::EnsureFishermanOwnerRole — `kind` stays reserved
  # for the 2 canonical admin rows and is never set on those. See User#fisherman?/dofi_officer_platform?
  # for how this drives access, and docs/registration/business-flow.md §9 for the incident that
  # motivated keeping "internal discriminator" columns like these off client-writable params.
  DOFI_OFFICER_PLATFORM = "dofi_officer".freeze
  FISHERMAN_PLATFORM = "fisherman".freeze
  PLATFORM_SCOPES = [DOFI_OFFICER_PLATFORM, FISHERMAN_PLATFORM].freeze
  RESERVED_FISHERMAN_ROLE_NAMES = %w[owner admin].freeze

  belongs_to :company_profile, optional: true
  has_many :permission_roles, dependent: :destroy
  has_many :permissions, through: :permission_roles
  has_many :users, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :company_profile_id }
  validates :kind, inclusion: { in: SYSTEM_KINDS }, uniqueness: true, allow_nil: true
  validates :platform_scope, presence: true, inclusion: { in: PLATFORM_SCOPES }
  validates :company_profile_id, presence: true, if: :fisherman_platform?
  validates :company_profile_id, absence: true, unless: :fisherman_platform?
  validate :reserved_fisherman_role_name_is_system_managed
  validate :system_managed_fisherman_role_name_is_immutable

  def fisherman_platform? = platform_scope == FISHERMAN_PLATFORM
  def dofi_officer_platform? = platform_scope == DOFI_OFFICER_PLATFORM
  def fisherman_owner_role? = fisherman_platform? && is_default?
  def fisherman_admin_role? = fisherman_platform? && is_default_admin?
  def system_managed_fisherman_role? = fisherman_owner_role? || fisherman_admin_role?

  # A Jetty Manager role or any fisherman-platform role is "external" — never assignable through the
  # DoFi Officer "Add User" flow, which only ever creates dofi_officer-platform accounts. See
  # Users::Create/Role.assignable_by_admin.
  def external? = kind == JETTY_MANAGER || fisherman_platform?

  def self.external = where(kind: JETTY_MANAGER).or(where(platform_scope: FISHERMAN_PLATFORM))
  def self.assignable_by_admin = where.not(id: external.select(:id))

  def self.assignable_by_fisherman(company_profile_id)
    where(platform_scope: FISHERMAN_PLATFORM, company_profile_id: company_profile_id)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id kind name description platform_scope company_profile_id is_default is_default_admin created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def reserved_fisherman_role_name_is_system_managed
    return unless fisherman_platform?
    return unless RESERVED_FISHERMAN_ROLE_NAMES.include?(normalized_name)
    return if system_managed_fisherman_role?

    errors.add(:name, "is reserved for system-managed Fisherman roles")
  end

  def system_managed_fisherman_role_name_is_immutable
    return unless fisherman_platform?

    errors.add(:name, "must remain Owner") if fisherman_owner_role? && normalized_name != "owner"
    errors.add(:name, "must remain Admin") if fisherman_admin_role? && normalized_name != "admin"
  end

  def normalized_name = name.to_s.strip.downcase
end

# == Schema Information
#
# Table name: roles
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  description        :text
#  is_default         :boolean          default(FALSE), not null
#  is_default_admin   :boolean          default(FALSE), not null
#  kind               :string
#  name               :string           not null
#  platform_scope     :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  company_profile_id :uuid
#
# Indexes
#
#  index_roles_on_company_profile_id                       (company_profile_id)
#  index_roles_on_company_profile_id_and_is_default        (company_profile_id) UNIQUE WHERE (is_default = true)
#  index_roles_on_company_profile_id_and_is_default_admin  (company_profile_id) UNIQUE WHERE (is_default_admin = true)
#  index_roles_on_company_profile_id_and_name              (company_profile_id,name) UNIQUE NULLS NOT DISTINCT
#  index_roles_on_kind                                     (kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
