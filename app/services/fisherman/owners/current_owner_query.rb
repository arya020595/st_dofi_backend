module Fisherman
  module Owners
    class CurrentOwnerQuery
      def self.call(...) = new.call(...)
      def self.relation(...) = new.relation(...)

      def call(company_profile)
        relation(company_profile).first
      end

      def relation(company_profile)
        User.kept.joins(:role).where(
          company_profile: company_profile,
          fisherman_status: User::FishermanLifecycle::OWNER_SLOT_STATUSES,
          roles: { platform_scope: Role::FISHERMAN_PLATFORM, is_default: true }
        )
      end
    end
  end
end
