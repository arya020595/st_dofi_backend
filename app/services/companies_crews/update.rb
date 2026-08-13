module CompaniesCrews
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(crew, attributes)
      ActiveRecord::Base.transaction do
        return Failure(crew) unless crew.update(attributes)

        crew.revert_to_pending_for_edit!
        CompanyProfiles::SyncApprovalStatus.mark_pending!(crew.company_profile)
      end

      Success(crew)
    end
  end
end
