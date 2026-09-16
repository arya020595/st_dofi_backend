module Admin
  class AccountsQuery
    def self.call(scope:, category:, status_values:)
      case category
      when "fisherman_account"
        fisherman_scope(scope, status_values)
      when "jetty_manager_account"
        jetty_manager_scope(scope, status_values)
      else
        combined_scope(scope, status_values)
      end
    end

    def self.fisherman_scope(scope, status_values)
      relation = scope.joins(:role).where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
      return relation if status_values.empty?

      relation.where(fisherman_status: fisherman_lifecycle_statuses(status_values))
    end
    private_class_method :fisherman_scope

    def self.jetty_manager_scope(scope, status_values)
      relation = scope.joins(:role).where(roles: { kind: Role::JETTY_MANAGER })
      return relation if status_values.empty?

      relation.where(status: status_values)
    end
    private_class_method :jetty_manager_scope

    def self.combined_scope(scope, status_values)
      return scope if status_values.empty?

      fisherman_scope(scope, status_values).or(jetty_manager_scope(scope, status_values))
    end
    private_class_method :combined_scope

    def self.fisherman_lifecycle_statuses(status_values)
      status_values.map { |value| value == "active" ? "active" : "suspended" }
    end
    private_class_method :fisherman_lifecycle_statuses
  end
end
