module ManifestSkipReasons
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      reason = ManifestSkipReason.new(attributes.merge(reference_id: next_reference_id))
      return Failure(reason) unless reason.save

      Success(reason)
    end

    private

    def next_reference_id
      next_num = ManifestSkipReason.where("reference_id LIKE ?", "REA-%")
                                   .maximum("CAST(SUBSTRING(reference_id FROM 5) AS INTEGER)") || 0
      format("REA-%03d", next_num + 1)
    end
  end
end
