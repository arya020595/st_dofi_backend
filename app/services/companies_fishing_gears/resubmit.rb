module CompaniesFishingGears
  class Resubmit
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(gear, actor:)
      return Failure(gear) unless gear.may_resubmit?

      gear.resubmit!(actor: actor)
      Success(gear)
    end
  end
end
