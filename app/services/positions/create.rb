module Positions
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      position = Position.new(attributes)
      return Failure(position) unless position.save

      Success(position)
    end
  end
end
