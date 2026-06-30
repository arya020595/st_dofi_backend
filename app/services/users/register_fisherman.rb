module Users
  class RegisterFisherman
    include Dry::Monads[:result]

    # Registration types backed by an existing CompanyProfile the registrant's ic_number must match;
    # "Small - Scale (Full-Time)" registrants are individual fishermen with no associated company.
    COMPANY_REGISTRATION_TYPES = ["Commercial", "Small-Scale (Company)"].freeze

    def self.call(...) = new.call(...)

    def call(attributes)
      user = User.new(attributes.merge(
                        role: fisherman_role,
                        company_profile: company_profile_for(attributes),
                        password: SecureRandom.base64(24),
                        status: "pending",
                        brunei_id_verified_at: Time.current
                      ))
      return Success(user) if user.save

      Failure(user)
    end

    private

    def fisherman_role
      Role.find_by!(reference_id: User::FISHERMAN_ROLE_REFERENCE_ID)
    end

    def company_profile_for(attributes)
      return nil unless COMPANY_REGISTRATION_TYPES.include?(attributes[:registration_type])

      CompanyProfile.kept.find_by!(ic_no: attributes[:ic_number])
    end
  end
end
