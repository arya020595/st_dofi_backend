module Fisherman
  class ReplaceCompanyContact
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(old_contact:, new_contact_attributes:, actor:, reason:)
      @old_contact = old_contact
      @new_contact_attributes = new_contact_attributes
      @actor = actor
      @reason = reason
      @old_user = old_contact.users.kept.first

      eligibility_failure = eligibility_failure_for_replacement
      return Failure(eligibility_failure) if eligibility_failure

      with_audited_user(actor) do
        replace_contact_transaction
      end
    end

    private

    attr_reader :old_contact, :new_contact_attributes, :actor, :reason, :old_user

    def eligibility_failure_for_replacement
      return :provisioned_user_not_found if old_user.nil?

      :source_not_replaceable unless old_user.provisioning_source == ProvisionUser::DOFI_COMPANY_PROFILE
    end

    def replace_contact_transaction
      result = nil
      User.transaction do
        result = replace_locked_contact
        raise ActiveRecord::Rollback if result.failure?
      end
      result
    end

    def replace_locked_contact
      old_user.with_lock do
        old_contact.with_lock do
          release_old_identity
          provision_replacement(new_contact)
        end
      end
    end

    def release_old_identity
      old_user.audit_comment = audit_comment("fisherman_replacement_revoke", reason)
      old_user.revoke_fisherman! if old_user.may_revoke_fisherman?
      old_contact.audit_comment = audit_comment("fisherman_replacement_contact_release", reason)
      old_contact.discard
    end

    def new_contact
      old_contact.company_profile.contacts.create!(replacement_contact_attributes)
    end

    def replacement_contact_attributes
      new_contact_attributes.merge(
        designation: old_contact.designation,
        audit_comment: audit_comment("fisherman_replacement_contact", reason)
      )
    end

    def provision_replacement(contact)
      ProvisionUser.call(
        company_profile: old_contact.company_profile,
        provisioning_source: ProvisionUser::DOFI_COMPANY_PROFILE,
        created_by: actor,
        name: contact.full_name,
        ic_number: contact.ic_no,
        company_profile_contact: contact
      )
    end
  end
end
