module CompaniesCaptains
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(captain, attributes)
      return Success(captain) if captain.update(attributes)

      Failure(captain)
    end
  end
end
