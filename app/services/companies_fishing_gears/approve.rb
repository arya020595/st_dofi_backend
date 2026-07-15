module CompaniesFishingGears
  class Approve
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(gear, actor:)
      return Failure(gear) unless gear.may_approve?

      gear.approve!(actor: actor)
      Success(gear)
    end
  end
end
