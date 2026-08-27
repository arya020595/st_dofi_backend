module Fisherman
  class OwnerManagementGuard
    def self.user_management_failure(...) = new.user_management_failure(...)

    def user_management_failure(actor:, target_user: nil, role: nil)
      return unless actor&.fisherman?
      return :cannot_manage_owner if target_user&.has_fisherman_owner_role?

      :cannot_assign_owner_role if role&.fisherman_owner_role?
    end
  end
end
