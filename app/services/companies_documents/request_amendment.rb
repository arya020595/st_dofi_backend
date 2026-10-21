module CompaniesDocuments
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(document, actor:, remarks:)
      return Failure(document) unless document.may_request_amendment?

      ActiveRecord::Base.transaction do
        document.request_amendment!(actor: actor, remarks: remarks)
        CompanyProfiles::SyncApprovalStatus.mark_pending!(document.company_profile)
        Notifications::ProfilingPublisher.call(event: :document_amendment_required, resource: document)
      end

      Success(document)
    end
  end
end
