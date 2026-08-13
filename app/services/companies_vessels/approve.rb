module CompaniesVessels
  class Approve
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, actor:)
      return Failure(vessel) unless vessel.may_approve?

      ActiveRecord::Base.transaction do
        vessel.approve!(actor: actor)
        approve_fishing_gears!(vessel, actor)
        CompanyProfiles::SyncApprovalStatus.refresh_after_review!(vessel.company_profile, actor: actor)
      end

      Success(vessel)
    end

    private

    def approve_fishing_gears!(vessel, actor)
      vessel.companies_fishing_gears.kept.find_each do |gear|
        next if gear.approved?

        gear.resubmit!(actor: actor) if gear.may_resubmit?
        gear.approve!(actor: actor) if gear.may_approve?
      end
    end
  end
end
