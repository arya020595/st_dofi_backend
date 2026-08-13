module CompaniesCrews
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(crew, actor:, remarks:)
      return Failure(crew) unless crew.may_request_amendment?

      ActiveRecord::Base.transaction do
        crew.request_amendment!(actor: actor, remarks: remarks)
        CompanyProfiles::SyncApprovalStatus.mark_pending!(crew.company_profile)
      end

      Success(crew)
    end
  end
end
