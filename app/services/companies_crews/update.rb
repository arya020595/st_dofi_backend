module CompaniesCrews
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(crew, attributes)
      return Success(crew) if crew.update(attributes)

      Failure(crew)
    end
  end
end
