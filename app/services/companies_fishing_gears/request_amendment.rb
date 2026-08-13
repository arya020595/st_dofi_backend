module CompaniesFishingGears
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(gear, actor:, remarks:)
      return Failure(gear) unless gear.may_request_amendment?

      ActiveRecord::Base.transaction do
        gear.request_amendment!(actor: actor, remarks: remarks)
        CompanyProfiles::SyncApprovalStatus.mark_pending!(gear.company_profile)
      end

      Success(gear)
    end
  end
end
