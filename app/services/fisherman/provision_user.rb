module Fisherman
  class ProvisionUser
    include Dry::Monads[:result]
    include AuditedOperation

    DOFI_COMPANY_PROFILE = "dofi_company_profile".freeze
    FISHERMAN_OWNER = "fisherman_owner".freeze

    def self.call(...) = new.call(...)

    def call(**attributes)
      @request = ProvisioningRequest.new(attributes)
      context_result = ProvisioningContext.call(request)
      return context_result if context_result.failure?

      create_user(context_result.value!)
    rescue ActiveRecord::RecordNotUnique
      Failure(conflict_after_unique_race)
    end

    private

    attr_reader :request

    def create_user(context)
      normalized_ic_number = IcNumbers::Normalize.call(context.ic_number)
      conflict = ic_conflict(normalized_ic_number)
      return Failure(conflict) if conflict

      persist_user(build_user(context, normalized_ic_number))
    end

    def persist_user(user)
      with_audited_user(request.created_by) do
        user.audit_comment = audit_comment("fisherman_provision", request.provisioning_source)
        return Success(user) if user.save
      end

      Failure(user)
    end

    def ic_conflict(normalized_ic_number)
      case CheckIcAvailability.call(normalized_ic_number: normalized_ic_number,
                                    company_profile: request.company_profile)
      in Success(status: :available)
        nil
      in Success(status: :existing_same_company)
        :ic_conflict_same_company
      in Success(status: :existing_other_company)
        :ic_conflict_other_company
      end
    end

    def build_user(context, normalized_ic_number)
      User.new(
        user_attributes(context, normalized_ic_number).merge(password: SecureRandom.base64(24))
      )
    end

    def user_attributes(context, normalized_ic_number)
      identity_attributes(context, normalized_ic_number).merge(provisioning_attributes(context))
    end

    def identity_attributes(context, normalized_ic_number)
      {
        name: context.name,
        ic_number: context.ic_number,
        normalized_ic_number: normalized_ic_number,
        designation: context.designation,
        registration_type: request.company_profile.registration_type
      }
    end

    def provisioning_attributes(context)
      {
        company_profile: request.company_profile,
        company_profile_contact: context.company_profile_contact,
        role: context.role,
        fisherman_status: context.fisherman_status,
        provisioning_source: request.provisioning_source,
        created_by: request.created_by
      }
    end

    def conflict_after_unique_race
      ic_conflict(IcNumbers::Normalize.call(request.ic_number)) || :ic_conflict_other_company
    end
  end
end
