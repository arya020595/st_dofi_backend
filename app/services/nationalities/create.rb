module Nationalities
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      nationality = Nationality.new(attributes)
      return Failure(nationality) unless nationality.save

      Success(nationality)
    end
  end
end
