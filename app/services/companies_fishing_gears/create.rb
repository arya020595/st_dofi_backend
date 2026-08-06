module CompaniesFishingGears
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, vessel, attributes)
      gear = company_profile.companies_fishing_gears.new(
        attributes.merge(companies_vessel: vessel, **fishing_gear_snapshot(attributes[:fishing_gear_id]))
      )

      ActiveRecord::Base.transaction do
        return Failure(gear) unless gear.save

        vessel.revert_to_pending_for_edit!
      end

      Success(gear)
    end

    private

    def fishing_gear_snapshot(fishing_gear_id)
      fishing_gear = FishingGear.find_by(id: fishing_gear_id)
      { fishing_gear_name: fishing_gear&.name, fishing_gear_type: fishing_gear&.gear_type,
        fishing_gear_fee: fishing_gear&.fee }
    end
  end
end
