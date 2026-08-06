module CompaniesFishingGears
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, vessel, attributes)
      gear = company_profile.companies_fishing_gears.new(
        attributes.merge(companies_vessel: vessel, **Snapshots.fishing_gear(attributes[:fishing_gear_id]))
      )

      ActiveRecord::Base.transaction do
        return Failure(gear) unless gear.save

        vessel.revert_to_pending_for_edit!
      end

      Success(gear)
    end
  end
end
