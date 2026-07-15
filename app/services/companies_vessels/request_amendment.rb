module CompaniesVessels
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, actor:, remarks:)
      return Failure(vessel) unless vessel.may_request_amendment?

      vessel.request_amendment!(actor: actor, remarks: remarks)
      Success(vessel)
    end
  end
end
