module Fisherman
  class UpdateProvisionalContact
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(contact:, attributes:, actor:, reason:)
      @contact = contact
      @attributes = attributes
      @reason = reason
      @user = contact.users.kept.first

      eligibility_failure = eligibility_failure_for_update
      return Failure(eligibility_failure) if eligibility_failure

      with_audited_user(actor) do
        User.transaction { user.with_lock { contact.with_lock { update_locked_contact } } }
      end
    end

    private

    attr_reader :contact, :attributes, :reason, :user

    def eligibility_failure_for_update
      return :provisioned_user_not_found if user.nil?

      :source_not_correctable unless source_a_user?
    end

    def update_locked_contact
      contact.audit_comment = audit_comment("fisherman_contact_correction", reason)
      return Failure(contact) unless contact.update(attributes)

      sync_user_after_contact_update
    end

    def sync_user_after_contact_update
      update_user_identity
      user.save!
      Success(user)
    end

    def source_a_user?
      user.provisioning_source == ProvisionUser::DOFI_COMPANY_PROFILE
    end

    def update_user_identity
      user.name = contact.full_name
      user.ic_number = contact.ic_no
      user.designation = contact.designation
      user.audit_comment = audit_comment("fisherman_identity_correction", reason)
    end
  end
end
