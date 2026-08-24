module CompanyProfiles
  class Create
    include Dry::Monads[:result]

    Result = Struct.new(:company_profile, :owner, :admin, :owner_user, :admin_user)

    def self.call(...) = new.call(...)

    ProvisioningFailed = Class.new(StandardError) do
      attr_reader :reason

      def initialize(reason)
        @reason = reason
        super(reason.to_s)
      end
    end

    def call(attributes, created_by:)
      result = nil

      ActiveRecord::Base.transaction { result = build_result!(attributes, created_by: created_by) }

      Success(result)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record)
    rescue ProvisioningFailed => e
      Failure(e.reason)
    end

    private

    def build_result!(attributes, created_by:)
      company_profile = CompanyProfile.create!(
        attributes.except(:owner, :admin).merge(dofi_registration_no: SecureRandom.uuid)
      )
      owner, owner_user, admin, admin_user = locked_contact_provisioning(company_profile, attributes, created_by)

      Result.new(company_profile, owner, admin, owner_user, admin_user)
    end

    def locked_contact_provisioning(company_profile, attributes, created_by)
      owner = owner_user = admin = admin_user = nil
      company_profile.with_lock do
        owner = create_contact!(company_profile, attributes[:owner], designation: "Owner")
        owner_user = provision_user!(company_profile, owner, created_by: created_by)
        admin = create_admin_contact(company_profile, attributes)
        admin_user = provision_user!(company_profile, admin, created_by: created_by) if admin
      end
      [owner, owner_user, admin, admin_user]
    end

    def create_admin_contact(company_profile, attributes)
      return unless admin_submitted?(attributes)

      create_contact!(company_profile, attributes[:admin], designation: "Admin")
    end

    def create_contact!(company_profile, contact_attributes, designation:)
      company_profile.contacts.create!(contact_attributes.merge(designation: designation))
    end

    def provision_user!(company_profile, contact, created_by:)
      result = provisioning_result(company_profile, contact, created_by)
      return result.value! if result.success?

      raise ProvisioningFailed, result.failure
    end

    def provisioning_result(company_profile, contact, created_by)
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
