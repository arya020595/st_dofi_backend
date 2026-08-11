module Users
  class RegisterFisherman
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # Every registration_type requires a pre-existing CompanyProfileContact matched by IC number —
    # for Commercial/Small-Scale (Company) this is an officer-profiled company's Owner/Admin; for
    # Small - Scale (Full-Time) it's the fisherman's own Owner contact on their individual-shaped
    # CompanyProfile (see CompanyProfile#individual?, which only relaxes which company-level fields
    # that profile requires — the person-level match still goes through CompanyProfileContact like
    # every other type). Both are pre-created the same way, via POST /api/v1/admin/company_profiles —
    # see docs/registration/registration-flow.md section 5 "Officer Profiling".
    #
    # registration_type is checked before the contact lookup, not left to User's own conditional
    # validation (validates :registration_type, if: :fisherman?) — that gate depends on a role being
    # assigned, and a role can only be assigned once a company is known via a matched contact, so an
    # unrecognized type with no matching contact would otherwise skip validation entirely instead of
    # surfacing a 422.
    def call(attributes)
      return invalid_registration_type_failure(attributes) unless valid_registration_type?(attributes)

      contact = matched_contact(attributes)
      return Failure(:contact_not_found) if contact.nil?

      user = rejected_user(attributes[:ic_number]) || User.new
      user.assign_attributes(build_attributes(attributes, contact, user: user))
      return Success(user) if user.save

      Failure(user)
    end

    private

    def valid_registration_type?(attributes)
      User::VALID_REGISTRATION_TYPES.include?(attributes[:registration_type])
    end

    def invalid_registration_type_failure(attributes)
      user = User.new(attributes)
      user.errors.add(:registration_type, :inclusion, value: attributes[:registration_type])
      Failure(user)
    end

    def matched_contact(attributes)
      CompanyProfileContact.kept.find_by(ic_no: attributes[:ic_number])
    end

    def build_attributes(attributes, contact)
      attributes.merge(role: Roles::EnsureFishermanOwnerRole.call(contact.company_profile),
                       password: SecureRandom.base64(24), status: "pending", brunei_id_verified_at: Time.current,
                       company_profile: contact.company_profile, company_profile_contact: contact,
                       designation: contact.designation)
    end
  end
end
