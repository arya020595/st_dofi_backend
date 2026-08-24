module Fisherman
  module Owners
    class RevokeAccess
      include Dry::Monads[:result]
      include Fisherman::AuditedOperation

      def self.call(...) = new.call(...)

      def call(user:, actor:, reason:)
        return Failure(:actor_not_authorized) unless actor&.dofi_officer_platform?
        return Failure(:not_owner) unless user.has_fisherman_owner_role?

        with_audited_user(actor) do
          User.transaction do
            user.company_profile.with_lock do
              user.with_lock { revoke_locked_owner(user, reason) }
            end
          end
        end
      end

      private

      def revoke_locked_owner(user, reason)
        return Failure(:not_current_owner) unless user.occupies_fisherman_owner_slot?

        user.audit_comment = audit_comment("fisherman_owner_revoke_access", reason)
        user.revoke_fisherman!
        Success(user)
      end
    end
  end
end
