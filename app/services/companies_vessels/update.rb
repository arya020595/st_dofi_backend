module CompaniesVessels
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, attributes)
      ActiveRecord::Base.transaction do
        return Failure(vessel) unless vessel.update(attributes)

        vessel.revert_to_pending_for_edit!
        CompanyProfiles::SyncApprovalStatus.mark_pending!(vessel.company_profile)
      end

      Success(vessel)
    end
  end
end
