module CompaniesCaptains
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(captain, actor:, remarks:)
      return Failure(captain) unless captain.may_request_amendment?

      captain.request_amendment!(actor: actor, remarks: remarks)
      Success(captain)
    end
  end
end
