module FishingGears
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      gear = FishingGear.new(attributes)
      return Failure(gear) unless gear.save

      Success(gear)
    end
  end
end
