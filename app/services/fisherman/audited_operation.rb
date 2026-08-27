module Fisherman
  module AuditedOperation
    private

    def with_audited_user(actor, &block)
      return block.call if actor.blank?

      Audited.audit_class.as_user(actor, &block)
    end

    def audit_comment(action, reason)
      "#{action}: #{reason.presence || 'No reason provided'}"
    end
  end
end
