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

      attributes.merge(Snapshots.fishing_gear(attributes[:fishing_gear_id]))
    end
  end
end
