module CompaniesDocuments
  class Approve
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(document, actor:)
      return Failure(document) unless document.may_approve?

      document.approve!(actor: actor)
      Success(document)
    end
  end
end
