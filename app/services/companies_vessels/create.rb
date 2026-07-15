module CompaniesVessels
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, attributes)
      vessel = company_profile.companies_vessels.new(attributes)
      return Failure(vessel) unless vessel.save

      Success(vessel)
    end
  end
end
