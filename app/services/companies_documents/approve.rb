module CompaniesDocuments
  class Approve
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(document, actor:)
      return Failure(document) unless document.may_approve?

      ActiveRecord::Base.transaction do
        document.approve!(actor: actor)
        CompanyProfiles::SyncApprovalStatus.refresh_after_review!(document.company_profile, actor: actor)
      end

      Success(document)
    end
  end
end
