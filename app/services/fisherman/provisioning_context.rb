module Fisherman
  class ProvisioningContext
    include Dry::Monads[:result]

    Context = Data.define(:fisherman_status, :role, :name, :ic_number, :company_profile_contact, :designation)

    def self.call(...) = new.call(...)

    def call(request)
      case request.provisioning_source
      when ProvisionUser::DOFI_COMPANY_PROFILE then source_a_context(request)
      when ProvisionUser::FISHERMAN_OWNER then source_b_context(request)
      else Failure(:invalid_provisioning_source)
      end
    end

    private

    def source_a_context(request)
      contact = request.company_profile_contact
      return Failure(:company_profile_contact_required) if contact.blank?
      return Failure(:company_profile_contact_mismatch) if contact.company_profile_id != request.company_profile.id

      role_result = role_for_contact(request.company_profile, contact)
      return role_result if role_result.failure?

      Success(build_source_a_context(contact, role_result.value!))
    end

    def role_for_contact(company_profile, contact)
      case contact.designation
      when "Owner" then owner_role_result(company_profile)
      when "Admin" then Success(Roles::EnsureFishermanAdminRole.call(company_profile))
      else Failure(:invalid_contact_designation)
      end
    end

    def owner_role_result(company_profile)
      return Failure(:owner_slot_occupied) if Owners::CurrentOwnerQuery.call(company_profile)

      Success(Roles::EnsureFishermanOwnerRole.call(company_profile))
    end

    def build_source_a_context(contact, role)
      Context.new("pending_approval", role, contact.full_name, contact.ic_no, contact, contact.designation)
    end

    def source_b_context(request)
      failure = source_b_role_failure(request)
      return Failure(failure) if failure

      Success(Context.new("claimable", request.role, request.name, request.ic_number, nil, nil))
    end

    def source_b_role_failure(request)
      return :role_required if request.role.blank?
      return :role_company_mismatch if request.role.company_profile_id != request.company_profile.id
      return :role_platform_mismatch unless request.role.fisherman_platform?
      return :cannot_assign_owner_role if request.role.fisherman_owner_role?
      return :cannot_assign_admin_role if request.role.fisherman_admin_role?

      nil
    end
  end
end
