module CompaniesFishingGears
  class Approve
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(gear, actor:)
      return Failure(gear) unless gear.may_approve?

      ActiveRecord::Base.transaction do
        gear.approve!(actor: actor)
        CompanyProfiles::SyncApprovalStatus.refresh_after_review!(gear.company_profile, actor: actor)
      end

      Success(gear)
    end
  end
end
