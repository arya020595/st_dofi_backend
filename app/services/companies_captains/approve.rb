module CompaniesCaptains
  class Approve
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(captain, actor:)
      return Failure(captain) unless captain.may_approve?

      captain.approve!(actor: actor)
      Success(captain)
    end
  end
end
