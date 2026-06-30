module Ports
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      port = Port.new(attributes.merge(reference_id: next_reference_id))
      return Failure(port) unless port.save

      Success(port)
    end

    private

    def next_reference_id
      next_num = Port.where("reference_id LIKE ?", "PT-%")
                     .maximum("CAST(SUBSTRING(reference_id FROM 4) AS INTEGER)") || 0
      format("PT-%03d", next_num + 1)
    end
  end
end
