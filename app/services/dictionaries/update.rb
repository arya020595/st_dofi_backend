module Dictionaries
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(dictionary, attributes)
      return Success(dictionary) if dictionary.update(attributes)

      Failure(dictionary)
    end
  end
end
