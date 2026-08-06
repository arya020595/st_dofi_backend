module CompaniesFishingGears
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(gear, attributes)
      ActiveRecord::Base.transaction do
        return Failure(gear) unless gear.update(attributes_for_update(attributes))

        gear.revert_to_pending_for_edit!
        gear.companies_vessel.revert_to_pending_for_edit!
      end

      Success(gear)
    end

    private

    def attributes_for_update(attributes)
      return attributes unless attributes.key?(:fishing_gear_id)

      attributes.merge(fishing_gear_snapshot(attributes[:fishing_gear_id]))
    end

    def fishing_gear_snapshot(fishing_gear_id)
      fishing_gear = FishingGear.find_by(id: fishing_gear_id)
      { fishing_gear_name: fishing_gear&.name, fishing_gear_type: fishing_gear&.gear_type,
        fishing_gear_fee: fishing_gear&.fee }
    end
  end
end
