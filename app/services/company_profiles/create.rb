module CompanyProfiles
  class Create
    include Dry::Monads[:result]

    Result = Struct.new(:company_profile, :owner, :admin)

    def self.call(...) = new.call(...)

    def call(attributes)
      result = nil

      ActiveRecord::Base.transaction { result = build_result!(attributes) }

      Success(result)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record)
    end

    private

    def build_result!(attributes)
      company_profile = CompanyProfile.create!(
        attributes.except(:owner, :admin).merge(dofi_registration_no: SecureRandom.uuid)
      )
      owner = create_contact!(company_profile, attributes[:owner], designation: "Owner")
      admin = create_contact!(company_profile, attributes[:admin], designation: "Admin") if admin_submitted?(attributes)

      Result.new(company_profile, owner, admin)
    end

    def create_contact!(company_profile, contact_attributes, designation:)
      company_profile.contacts.create!(contact_attributes.merge(designation: designation))
    end

    def admin_submitted?(attributes)
      attributes[:admin].present? && attributes[:admin].to_h.values.any?(&:present?)
    end
  end
end
