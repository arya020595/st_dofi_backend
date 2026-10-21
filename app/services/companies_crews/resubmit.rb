module CompaniesCrews
  class Resubmit
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(crew, actor:)
      return Failure(crew) unless crew.may_resubmit?

      crew.resubmit!(actor: actor)
      Success(crew)
    end
  end
end
