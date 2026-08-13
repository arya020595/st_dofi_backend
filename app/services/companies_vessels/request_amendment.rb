module CompaniesVessels
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, actor:, remarks:)
      return Failure(vessel) unless vessel.may_request_amendment?

      ActiveRecord::Base.transaction do
        vessel.request_amendment!(actor: actor, remarks: remarks)
        CompanyProfiles::SyncApprovalStatus.mark_pending!(vessel.company_profile)
      end

      Success(vessel)
    end
  end
end
