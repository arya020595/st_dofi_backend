module CompaniesCrews
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(crew, attributes)
      return Failure(crew) unless crew.update(attributes)

      crew.revert_to_pending_for_edit!
      Success(crew)
    end
  end
end
