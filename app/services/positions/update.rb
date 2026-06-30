module Positions
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(position, attributes)
      return Success(position) if position.update(attributes)

      Failure(position)
    end
  end
end
