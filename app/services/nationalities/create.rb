module Nationalities
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      nationality = Nationality.new(attributes.merge(reference_id: next_reference_id))
      return Failure(nationality) unless nationality.save

      Success(nationality)
    end

    private

    def next_reference_id
      next_num = Nationality.where("reference_id LIKE ?", "NT-%")
                            .maximum("CAST(SUBSTRING(reference_id FROM 4) AS INTEGER)") || 0
      format("NT-%03d", next_num + 1)
    end
  end
end
