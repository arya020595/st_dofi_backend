module FishingGearDetails
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(detail, attributes)
      return Success(detail) if detail.update(attributes)

      Failure(detail)
    end
  end
end
