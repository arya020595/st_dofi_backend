module CompaniesCrews
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, attributes)
      crew = company_profile.companies_crews.new(attributes)

      ActiveRecord::Base.transaction do
        return Failure(crew) unless crew.save

        CompanyProfiles::SyncApprovalStatus.mark_pending!(company_profile)
      end

      Success(crew)
    end
  end
end
