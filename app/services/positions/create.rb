module Positions
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      position = Position.new(attributes.merge(reference_id: next_reference_id))
      return Failure(position) unless position.save

      Success(position)
    end

    private

    def next_reference_id
      next_num = Position.where("reference_id LIKE ?", "POS-%")
                         .maximum("CAST(SUBSTRING(reference_id FROM 5) AS INTEGER)") || 0
      format("POS-%03d", next_num + 1)
    end
  end
end
