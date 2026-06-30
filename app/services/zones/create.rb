module Zones
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      zone = Zone.new(attributes)
      return Failure(zone) unless zone.save

      Success(zone)
    end
  end
end
