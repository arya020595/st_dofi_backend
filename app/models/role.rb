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

  belongs_to :company_profile, optional: true
  has_many :permission_roles, dependent: :destroy
  has_many :permissions, through: :permission_roles
  has_many :users, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :company_profile_id }
  validates :kind, inclusion: { in: SYSTEM_KINDS }, uniqueness: true, allow_nil: true
  validates :platform_scope, presence: true, inclusion: { in: PLATFORM_SCOPES }
  validates :company_profile_id, presence: true, if: :fisherman_platform?
  validates :company_profile_id, absence: true, unless: :fisherman_platform?

  def fisherman_platform? = platform_scope == FISHERMAN_PLATFORM
  def dofi_officer_platform? = platform_scope == DOFI_OFFICER_PLATFORM

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
end

# == Schema Information
#
# Table name: roles
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  description        :text
#  is_default         :boolean          default(FALSE), not null
#  kind               :string
#  name               :string           not null
#  platform_scope     :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  company_profile_id :uuid
#
# Indexes
#
#  index_roles_on_company_profile_id                 (company_profile_id)
#  index_roles_on_company_profile_id_and_is_default  (company_profile_id) UNIQUE WHERE (is_default = true)
#  index_roles_on_company_profile_id_and_name        (company_profile_id,name) UNIQUE NULLS NOT DISTINCT
#  index_roles_on_kind                               (kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
