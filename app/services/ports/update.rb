module Ports
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(port, attributes)
      return Success(port) if port.update(attributes)

      Failure(port)
    end
  end
end
