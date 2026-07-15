module CompaniesCrews
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, attributes)
      crew = company_profile.companies_crews.new(attributes)
      return Failure(crew) unless crew.save

      Success(crew)
    end
  end
end
