module CompaniesFishingGears
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(gear, attributes)
      return Failure(gear) unless gear.update(attributes)

      gear.revert_to_pending_for_edit!
      Success(gear)
    end
  end
end
