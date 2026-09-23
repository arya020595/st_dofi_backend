module CompanyProfiles
  class Update
    include Dry::Monads[:result, :do]
    include Fisherman::AuditedOperation

    def self.call(...) = new.call(...)

    def call(company_profile, attributes, updated_by:)
      company_profile.with_lock do
        yield update_profile(company_profile, attributes)
        yield sync_owner_contact(company_profile, attributes[:owner], updated_by)
        yield sync_admin_contact(company_profile, attributes[:admin], updated_by)
      end
      Success(company_profile.reload)
    end

    private

    def update_profile(company_profile, attributes)
      return Success(company_profile) if company_profile.update(attributes.except(:owner, :admin))

      Failure(company_profile)
    end

    def sync_owner_contact(company_profile, attributes, updated_by)
      return Success(nil) if attributes.blank?

      contact = company_profile.owner_contact
      return Failure(:owner_contact_not_found) if contact.nil?

      sync_contact(company_profile, contact, "Owner", attributes, updated_by)
    end

    def sync_admin_contact(company_profile, attributes, updated_by)
      return Success(nil) if attributes.blank?

      sync_contact(company_profile, company_profile.admin_contact, "Admin", attributes, updated_by)
    end

    def sync_contact(company_profile, contact, designation, attributes, updated_by)
      return create_contact(company_profile, designation, attributes, updated_by) if contact.nil?

      contact_user = contact.users.kept.first
      return update_and_provision_contact(company_profile, contact, attributes, updated_by) if contact_user.nil?
      return replace_claimed_contact(contact, attributes, updated_by) if contact_user.claimed_at.present?

      update_provisioned_contact(contact, attributes, updated_by)
    end

    # A claimed identity has already been verified via BruneiID for the OLD data — overwriting it in
    # place would leave the record claiming verification for data BruneiID never actually verified.
    # Instead: revoke the old (now-incorrect) identity so it can no longer log in, and provision a
    # fresh, unclaimed contact + user for the corrected identity to claim.
    def replace_claimed_contact(contact, attributes, updated_by)
      Fisherman::ReplaceCompanyContact.call(
        old_contact: contact,
        new_contact_attributes: attributes,
        actor: updated_by,
        reason: "Company profile update"
      )
    end

    def update_provisioned_contact(contact, attributes, updated_by)
      Fisherman::UpdateProvisionalContact.call(
        contact: contact,
        attributes: attributes,
        actor: updated_by,
        reason: "Company profile update"
      )
    end

    def update_and_provision_contact(company_profile, contact, attributes, updated_by)
      contact.assign_attributes(attributes)
      yield save_contact(contact, updated_by, action: "company_profile_contact_update")
      provision_contact_user(company_profile, contact, updated_by)
    end

    def create_contact(company_profile, designation, attributes, updated_by)
      contact = company_profile.contacts.build(attributes.merge(designation: designation))
      yield save_contact(contact, updated_by, action: "company_profile_contact_create")
      provision_contact_user(company_profile, contact, updated_by)
    end

    def save_contact(contact, updated_by, action:)
      with_audited_user(updated_by) do
        contact.audit_comment = audit_comment(action, "Company profile update")
        contact.save ? Success(contact) : Failure(contact)
      end
    end

    def provision_contact_user(company_profile, contact, updated_by)
      Fisherman::ProvisionUser.call(
        company_profile: company_profile,
        provisioning_source: Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE,
        created_by: updated_by,
        name: contact.full_name,
        ic_number: contact.ic_no,
        company_profile_contact: contact
      )
    end
  end
end
