module CompaniesFishingGears
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, vessel, attributes)
      gear = company_profile.companies_fishing_gears.new(attributes.merge(companies_vessel: vessel))
      return Failure(gear) unless gear.save

      Success(gear)
    end
  end
end
