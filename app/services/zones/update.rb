module Zones
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(zone, attributes)
      return Success(zone) if zone.update(attributes)

      Failure(zone)
    end
  end
end
