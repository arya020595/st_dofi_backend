module ManifestSkipReasons
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(reason, attributes)
      return Success(reason) if reason.update(attributes)

      Failure(reason)
    end
  end
end
