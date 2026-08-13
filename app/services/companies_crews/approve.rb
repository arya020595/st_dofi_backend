module CompaniesCrews
  class Approve
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(crew, actor:)
      return Failure(crew) unless crew.may_approve?

      ActiveRecord::Base.transaction do
        crew.approve!(actor: actor)
        CompanyProfiles::SyncApprovalStatus.refresh_after_review!(crew.company_profile, actor: actor)
      end

      Success(crew)
    end
  end
end
