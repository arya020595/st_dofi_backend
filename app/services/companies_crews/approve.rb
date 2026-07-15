module CompaniesCrews
  class Approve
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(crew, actor:)
      return Failure(crew) unless crew.may_approve?

      crew.approve!(actor: actor)
      Success(crew)
    end
  end
end
