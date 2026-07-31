module CompaniesDocuments
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(document, actor:, remarks:)
      return Failure(document) unless document.may_request_amendment?

      document.request_amendment!(actor: actor, remarks: remarks)
      Success(document)
    end
  end
end
