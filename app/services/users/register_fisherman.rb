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
    def call(attributes)
      contact = matched_contact(attributes)
      return Failure(:contact_not_found) if contact.nil? && valid_registration_type?(attributes)

      user = User.new(build_attributes(attributes, contact))
      return Success(user) if user.save

      Failure(user)
    end

    private

    # Only attempt the IC match for a recognized type — an unrecognized registration_type should
    # surface the model's own inclusion-validation error (422), not a misleading "no contact
    # matches" (404).
    def valid_registration_type?(attributes)
      User::VALID_REGISTRATION_TYPES.include?(attributes[:registration_type])
    end

    def matched_contact(attributes)
      return nil unless valid_registration_type?(attributes)

      CompanyProfileContact.kept.find_by(ic_no: attributes[:ic_number])
    end

    def build_attributes(attributes, contact)
      base = attributes.merge(role: fisherman_role, password: SecureRandom.base64(24), status: "pending",
                              brunei_id_verified_at: Time.current)
      return base if contact.nil?

      base.merge(company_profile: contact.company_profile, company_profile_contact: contact,
                 designation: contact.designation)
    end

    def fisherman_role
      Role.find_by!(kind: Role::FISHERMAN)
    end
  end
end
