module CompaniesFishingGears
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, attributes)
      gear = company_profile.companies_fishing_gears.new(attributes)
      return Failure(gear) unless gear.save

      Success(gear)
    end
  end
end
