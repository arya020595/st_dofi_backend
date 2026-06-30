module FishingGears
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      gear = FishingGear.new(attributes.merge(reference_id: next_reference_id))
      return Failure(gear) unless gear.save

      Success(gear)
    end

    private

    def next_reference_id
      next_num = FishingGear.where("reference_id LIKE ?", "FG-%")
                            .maximum("CAST(SUBSTRING(reference_id FROM 4) AS INTEGER)") || 0
      format("FG-%03d", next_num + 1)
    end
  end
end
