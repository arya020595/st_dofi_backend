module Fisherman
  class UpdateProvisionalContact
    include Dry::Monads[:result]
    include AuditedOperation

    IDENTITY_SENSITIVE_FIELDS = %i[full_name ic_no].freeze

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
      return :identity_locked if user.claimed_at.present?

      :source_not_correctable unless source_a_user?
    end

    def update_locked_contact
      original_values = identity_values
      contact.audit_comment = audit_comment("fisherman_contact_correction", reason)
      return Failure(contact) unless contact.update(attributes)

      sync_user_after_contact_update(identity_changed?(original_values))
    end

    def sync_user_after_contact_update(identity_changed)
      update_user_identity
      return reset_approval! if identity_changed && user.fisherman_status == "claimable"

      user.save!
      Success(user)
    end

    def source_a_user?
      user.provisioning_source == ProvisionUser::DOFI_COMPANY_PROFILE
    end

    def identity_values
      contact.slice(*IDENTITY_SENSITIVE_FIELDS.map(&:to_s))
    end

    def identity_changed?(original_values)
      IDENTITY_SENSITIVE_FIELDS.any? { |field| original_values.fetch(field.to_s) != contact.public_send(field) }
    end

    def update_user_identity
      user.name = contact.full_name
      user.ic_number = contact.ic_no
      user.designation = contact.designation
      user.audit_comment = audit_comment("fisherman_identity_correction", reason)
    end

    def reset_approval!
      return Failure(:not_resettable) unless user.may_reset_approval_fisherman?

      user.approved_at = nil
      user.approved_by = nil
      user.audit_comment = audit_comment("fisherman_approval_reset", reason)
      user.reset_approval_fisherman!
    end
  end
end
