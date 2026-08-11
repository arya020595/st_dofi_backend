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
      sanitized = attributes.except(:usage_value)
      return sanitized unless sanitized.key?(:fishing_gear_id)

      sanitized.merge(Snapshots.fishing_gear(sanitized[:fishing_gear_id]))
    end
  end
end
