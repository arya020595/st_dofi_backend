class Permission < ApplicationRecord
  # Deliberately 3 values where Role::PLATFORM_SCOPES has 2 — a role always belongs to exactly one
  # platform, but a permission can be usable by both ("shared", e.g. companies_crews.create, used by
  # both a fisherman's own self-service form and an officer profiling on their behalf via the same
  # dual-mounted controller). Do not "simplify" this to reuse Role::PLATFORM_SCOPES.
  DOFI_OFFICER_PLATFORM = "dofi_officer".freeze
  FISHERMAN_PLATFORM = "fisherman".freeze
  SHARED_PLATFORM = "shared".freeze
  PLATFORM_SCOPES = [DOFI_OFFICER_PLATFORM, FISHERMAN_PLATFORM, SHARED_PLATFORM].freeze
  FISHERMAN_ROLE_CONFIG_HIDDEN_GROUPS = %w[
    ports zones fishing_gears nationalities positions skip_reasons companies_fishing_gears
    manifest_expenses manifest_minor_fishermen capture_reports manifest_list manifest_form
  ].freeze

  has_many :permission_roles, dependent: :destroy
  has_many :roles, through: :permission_roles

  scope :visible_for_fisherman_role_config, lambda {
    filtered = FISHERMAN_ROLE_CONFIG_HIDDEN_GROUPS.reduce(all) do |relation, group|
      relation.where.not("code LIKE ?", "#{group}.%")
    end

    filtered
      .where.not("code LIKE ?", "%.list")
      .where.not(code: %w[profiling.create profiling.update profiling.delete profiling.list])
  }

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :platform_scope, presence: true, inclusion: { in: PLATFORM_SCOPES }

  # The permission codes a role on the given platform may be assigned — its own platform's codes,
  # plus anything shared. Used by Roles::Create/Update to reject cross-platform assignment.
  def self.assignable_to(role_platform_scope) = where(platform_scope: [role_platform_scope, SHARED_PLATFORM])

  def self.ransackable_attributes(_auth_object = nil)
    %w[id code name platform_scope created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: permissions
# Database name: primary
#
#  id             :uuid             not null, primary key
#  code           :string           not null
#  name           :string           not null
#  platform_scope :string           default("shared"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_permissions_on_code  (code) UNIQUE
#
