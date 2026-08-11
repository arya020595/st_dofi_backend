module CompaniesFishingGears
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, vessel, attributes)
      gear = company_profile.companies_fishing_gears.new(build_attributes(attributes, vessel))

      ActiveRecord::Base.transaction do
        return Failure(gear) unless gear.save

        vessel.revert_to_pending_for_edit!
      end

      Success(gear)
    end

    private

    def build_attributes(attributes, vessel)
      sanitized_attributes(attributes).merge(
        companies_vessel: vessel,
        usage_value: 0,
        **Snapshots.fishing_gear(attributes[:fishing_gear_id])
      )
    end

    def sanitized_attributes(attributes)
      attributes.except(:usage_value)
    end
  end
end
