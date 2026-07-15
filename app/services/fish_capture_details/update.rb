module FishCaptureDetails
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(detail, attributes)
      price = (attributes[:price_per_kg] || detail.price_per_kg).to_f
      amount = (attributes[:amount_captured_kg] || detail.amount_captured_kg).to_f
      return Success(detail) if detail.update(attributes.merge(overall_total: price * amount))

      Failure(detail)
    end
  end
end
