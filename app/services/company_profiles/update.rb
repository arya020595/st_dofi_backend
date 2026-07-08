module CompanyProfiles
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, attributes)
      return Success(company_profile) if company_profile.update(attributes)

      Failure(company_profile)
    end
  end
end
