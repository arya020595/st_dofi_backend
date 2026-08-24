module Fisherman
  class ReassignClaimedUser
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(**attributes)
      @attributes = attributes
      validation_failure = validation_failure_for_reassignment
      return Failure(validation_failure) if validation_failure

      reassign_with_lock
    end

    private

    attr_reader :attributes

    def validation_failure_for_reassignment
      return :not_claimed if user.claimed_at.blank?
      return :company_profile_contact_mismatch unless contact_belongs_to_company?
      return :role_company_mismatch unless role_belongs_to_company?

      :role_platform_mismatch unless role.fisherman_platform?
    end

    def reassign_with_lock
      with_audited_user(actor) do
        user.with_lock { reassign_locked_user }
      end
    end

    def reassign_locked_user
      return Failure(:not_claimed) if user.claimed_at.blank?

      user.assign_attributes(reassignment_attributes)
      user.audit_comment = audit_comment("fisherman_claimed_reassignment", reason)
      save_reassigned_user
    end

    def save_reassigned_user
      user.save ? Success(user) : Failure(user)
    end

    def reassignment_attributes
      { company_profile: company_profile, company_profile_contact: company_profile_contact, role: role }
    end

    def contact_belongs_to_company?
      company_profile_contact.company_profile_id == company_profile.id
    end

    def role_belongs_to_company?
      role.company_profile_id == company_profile.id
    end

    def user = attributes.fetch(:user)
    def company_profile = attributes.fetch(:company_profile)
    def company_profile_contact = attributes.fetch(:company_profile_contact)
    def role = attributes.fetch(:role)
    def actor = attributes.fetch(:actor)
    def reason = attributes.fetch(:reason)
  end
end
