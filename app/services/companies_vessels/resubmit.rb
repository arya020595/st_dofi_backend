module CompaniesVessels
  class Resubmit
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, actor:)
      return Failure(vessel) unless vessel.may_resubmit?

      vessel.resubmit!(actor: actor)
      Success(vessel)
    end
  end
end
