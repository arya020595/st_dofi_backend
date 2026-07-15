module CompaniesFishingGears
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(gear, actor:, remarks:)
      return Failure(gear) unless gear.may_request_amendment?

      gear.request_amendment!(actor: actor, remarks: remarks)
      Success(gear)
    end
  end
end
