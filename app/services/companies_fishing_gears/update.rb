module CompaniesFishingGears
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(gear, attributes)
      ActiveRecord::Base.transaction do
        return Failure(gear) unless gear.update(attributes)

        gear.revert_to_pending_for_edit!
        gear.companies_vessel.revert_to_pending_for_edit!
      end

      Success(gear)
    end
  end
end
