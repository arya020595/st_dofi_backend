module CompaniesCaptains
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, attributes)
      captain = company_profile.companies_captains.new(attributes)
      return Failure(captain) unless captain.save

      Success(captain)
    end
  end
end
