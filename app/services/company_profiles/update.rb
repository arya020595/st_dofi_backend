module CompanyProfiles
  class Update
    include Dry::Monads[:result]

    ContactSyncFailed = Class.new(StandardError) do
      attr_reader :failure

      def initialize(failure)
        @failure = failure
        super(failure.to_s)
      end
    end

    def self.call(...) = new.call(...)

    def call(company_profile, attributes, updated_by:)
      update_with_contacts!(company_profile, attributes, updated_by)
      Success(company_profile.reload)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record)
    rescue ContactSyncFailed => e
      Failure(e.failure)
    end

    private

    def update_with_contacts!(company_profile, attributes, updated_by)
      CompanyProfile.transaction do
        company_profile.with_lock do
          update_profile!(company_profile, attributes)
          sync_contact!(company_profile, "Owner", attributes[:owner], updated_by)
          sync_contact!(company_profile, "Admin", attributes[:admin], updated_by)
        end
      end
    end

    def update_profile!(company_profile, attributes)
      company_profile.update!(attributes.except(:owner, :admin))
    end

    def sync_contact!(company_profile, designation, attributes, updated_by)
      return if attributes.blank?

      contact = find_contact!(company_profile, designation)
      return create_admin!(company_profile, attributes, updated_by) if contact.nil?

      return update_and_provision_contact!(company_profile, contact, attributes, updated_by) if contact.users.kept.none?

      update_provisioned_contact!(contact, attributes, updated_by)
    end

    def find_contact!(company_profile, designation)
      contact = company_profile.contacts.kept.find_by(designation: designation)
      return contact if contact || designation == "Admin"

      raise ContactSyncFailed, :owner_contact_not_found
    end

    def update_provisioned_contact!(contact, attributes, updated_by)
      result = Fisherman::UpdateProvisionalContact.call(
        contact: contact,
        attributes: attributes,
        actor: updated_by,
        reason: "Company profile update",
        allow_claimed_identity_update: updated_by.dofi_officer_platform?
      )
      raise ContactSyncFailed, result.failure if result.failure?
    end

    def update_and_provision_contact!(company_profile, contact, attributes, updated_by)
      contact.update!(attributes)
      provision_contact_user!(company_profile, contact, updated_by)
    end

    def create_admin!(company_profile, attributes, updated_by)
      contact = company_profile.contacts.create!(attributes.merge(designation: "Admin"))
      provision_contact_user!(company_profile, contact, updated_by)
    end

    def provision_contact_user!(company_profile, contact, updated_by)
      result = Fisherman::ProvisionUser.call(
        company_profile: company_profile,
        provisioning_source: Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE,
        created_by: updated_by,
        name: contact.full_name,
        ic_number: contact.ic_no,
        company_profile_contact: contact
      )
      raise ContactSyncFailed, result.failure if result.failure?
    end
  end
end
