module Ports
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      port = Port.new(attributes)
      return Failure(port) unless port.save

      Success(port)
    end
  end
end
