module CompanyProfiles
  class Create
    include Dry::Monads[:result, :do]

    Result = Struct.new(:company_profile, :owner, :admin, :owner_user, :admin_user)

    def self.call(...) = new.call(...)

    def call(attributes, created_by:)
      result = nil
      ActiveRecord::Base.transaction { result = yield build_result(attributes, created_by) }
      Success(result)
    end

    private

    def build_result(attributes, created_by)
      company_profile = yield create_profile(attributes)
      owner, owner_user, admin, admin_user = yield locked_contact_provisioning(company_profile, attributes, created_by)

      Success(Result.new(company_profile, owner, admin, owner_user, admin_user))
    end

    def create_profile(attributes)
      company_profile = CompanyProfile.new(
        attributes.except(:owner, :admin).merge(dofi_registration_no: SecureRandom.uuid)
      )
      return Failure(company_profile) unless company_profile.save

      company_profile.reload
      Success(company_profile)
    end

    def locked_contact_provisioning(company_profile, attributes, created_by)
      owner = owner_user = admin = admin_user = nil
      company_profile.with_lock do
        owner = yield create_contact(company_profile, "Owner", attributes[:owner])
        owner_user = yield provision_user(company_profile, owner, created_by)
        admin = yield create_admin_contact(company_profile, attributes)
        admin_user = yield provision_admin_user(company_profile, admin, created_by)
      end
      Success([owner, owner_user, admin, admin_user])
    end

    def create_admin_contact(company_profile, attributes)
      return Success(nil) unless admin_submitted?(attributes)

      create_contact(company_profile, "Admin", attributes[:admin])
    end

    def create_contact(company_profile, designation, contact_attributes)
      contact = company_profile.contacts.new(contact_attributes.merge(designation: designation))
      return Failure(contact) unless contact.save

      Success(contact)
    end

    def provision_admin_user(company_profile, admin, created_by)
      return Success(nil) if admin.nil?

      provision_user(company_profile, admin, created_by)
    end

    def provision_user(company_profile, contact, created_by)
      Fisherman::ProvisionUser.call(
        company_profile: company_profile,
        provisioning_source: Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE,
        created_by: created_by,
        name: contact.full_name,
        ic_number: contact.ic_no,
        company_profile_contact: contact
      )
    end

    def admin_submitted?(attributes)
      attributes[:admin].present? && attributes[:admin].to_h.values.any?(&:present?)
    end
  end
end
