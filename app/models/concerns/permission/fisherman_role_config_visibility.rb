module Permission::FishermanRoleConfigVisibility
  extend ActiveSupport::Concern

  FISHERMAN_ROLE_CONFIG_HIDDEN_GROUPS = %w[
    ports zones fishing_gears nationalities positions skip_reasons companies_fishing_gears
    manifest_expenses manifest_minor_fishermen capture_reports manifest_list manifest_form
  ].freeze

  included do
    scope :visible_for_fisherman_role_config, lambda {
      filtered = FISHERMAN_ROLE_CONFIG_HIDDEN_GROUPS.reduce(all) do |relation, group|
        relation.where.not("code LIKE ?", "#{group}.%")
      end

      filtered
        .where.not("code LIKE ?", "%.list")
        .where.not(code: %w[profiling.create profiling.update profiling.delete profiling.list])
    }
  end
end
