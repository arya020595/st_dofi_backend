module Dictionaries
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # entries: Array of permitted params hashes, each optionally including :image
    def call(entries)
      dictionaries = build_all(entries)

      invalid = dictionaries.reject(&:valid?)
      return Failure(invalid.first) if invalid.any?

      Dictionary.transaction { dictionaries.each(&:save!) }

      Success(dictionaries)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record)
    end

    private

    def build_all(entries)
      # Reserve sequential reference IDs for the whole batch upfront so concurrent
      # bulk inserts don't race on the same max() value inside a transaction.
      next_num = Dictionary.where("reference_id LIKE ?", "SP-%")
                           .maximum("CAST(SUBSTRING(reference_id FROM 4) AS INTEGER)") || 0

      entries.map.with_index(1) do |attrs, offset|
        image = attrs.delete(:image)
        ref_id = format("SP-%04d", next_num + offset)
        Dictionary.new(attrs.merge(reference_id: ref_id)).tap do |d|
          d.image.attach(image) if image.present?
        end
      end
    end
  end
end
