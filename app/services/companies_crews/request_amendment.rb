module CompaniesCrews
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(crew, actor:, remarks:)
      return Failure(crew) unless crew.may_request_amendment?

      crew.request_amendment!(actor: actor, remarks: remarks)
      Success(crew)
    end
  end
end
