module Nationalities
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(nationality, attributes)
      return Success(nationality) if nationality.update(attributes)

      Failure(nationality)
    end
  end
end
