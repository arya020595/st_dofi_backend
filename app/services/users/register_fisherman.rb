module Users
  class RegisterFisherman
    include Dry::Monads[:result]

    # Registration types backed by an existing CompanyProfile the registrant's ic_number must match;
    # "Small - Scale (Full-Time)" registrants are individual fishermen with no associated company.
    COMPANY_REGISTRATION_TYPES = ["Commercial", "Small-Scale (Company)"].freeze

    def self.call(...) = new.call(...)

    def call(attributes)
      contact = contact_for(attributes)
      # contact_for returns nil both when the type has no company to match and when the match
      # fails; only the latter (a company type with no match) is a failure worth reporting.
      return Failure(:contact_not_found) if company_registration?(attributes) && contact.nil?

      user = User.new(build_attributes(attributes, contact))
      return Success(user) if user.save

      Failure(user)
    end

    private

    def company_registration?(attributes)
      COMPANY_REGISTRATION_TYPES.include?(attributes[:registration_type])
    end

    def build_attributes(attributes, contact)
      attributes.merge(role: fisherman_role, company_profile: contact&.company_profile,
                       company_profile_contact: contact, password: SecureRandom.base64(24),
                       status: "pending", brunei_id_verified_at: Time.current,
                       **(contact ? { designation: contact.designation } : {}))
    end

    def fisherman_role
      Role.find_by!(kind: Role::FISHERMAN)
    end

    def contact_for(attributes)
      return nil unless company_registration?(attributes)

      CompanyProfileContact.kept.find_by(ic_no: attributes[:ic_number])
    end
  end
end
