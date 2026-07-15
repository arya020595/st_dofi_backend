module CompaniesFishingGears
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(gear, attributes)
      return Success(gear) if gear.update(attributes)

      Failure(gear)
    end
  end
end
