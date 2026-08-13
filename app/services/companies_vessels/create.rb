module CompaniesVessels
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, attributes)
      vessel = company_profile.companies_vessels.new(attributes)

      ActiveRecord::Base.transaction do
        return Failure(vessel) unless vessel.save

        CompanyProfiles::SyncApprovalStatus.mark_pending!(company_profile)
      end

      Success(vessel)
    end
  end
end
