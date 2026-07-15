module CompaniesVessels
  class Approve
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, actor:)
      return Failure(vessel) unless vessel.may_approve?

      vessel.approve!(actor: actor)
      Success(vessel)
    end
  end
end
