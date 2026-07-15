module CompaniesCaptains
  class Resubmit
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(captain, actor:)
      return Failure(captain) unless captain.may_resubmit?

      captain.resubmit!(actor: actor)
      Success(captain)
    end
  end
end
